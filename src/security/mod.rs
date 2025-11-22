//! Sandbox Security Module
//!
//! This module implements filesystem path validation for the nu-mcp sandbox.
//!
//! ## Validation Strategy
//!
//! The module uses a two-tier validation approach:
//!
//! 1. **Whitelist Check**: Commands matching safe patterns bypass path validation
//!    - API commands (gh api, kubectl get /apis, argocd app, etc.)
//!    - HTTP clients with URLs
//!    - Other tools with non-filesystem path arguments
//!
//! 2. **Path Validation**: Remaining commands undergo filesystem path checks
//!    - Extract non-quoted tokens (respects Nushell quoting)
//!    - Identify potential filesystem paths
//!    - Verify paths don't escape sandbox directory
//!
//! ## Adding Whitelist Patterns
//!
//! To add new safe patterns, edit `get_safe_command_patterns()` and add a regex.
//! See `docs/security.md` for detailed instructions.

use regex::Regex;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

/// Safe command patterns that bypass path validation
/// These patterns match commands that use path-like arguments but are NOT filesystem paths
/// Examples: API endpoints, resource identifiers, URL paths, etc.
fn get_safe_command_patterns() -> &'static Vec<Regex> {
    static PATTERNS: OnceLock<Vec<Regex>> = OnceLock::new();
    PATTERNS.get_or_init(|| {
        vec![
            // GitHub CLI - API endpoint patterns
            // Matches: gh api /repos/owner/repo/... or gh api repos/owner/repo/...
            Regex::new(r"^gh\s+api\s+").unwrap(),
            // kubectl - API resource paths
            // Matches: kubectl get /apis/... or kubectl <verb> /api/...
            Regex::new(r"^kubectl\s+(get|describe|delete|patch|create)\s+/api").unwrap(),
            // argocd - Application paths
            // Matches: argocd app <verb> /argocd/...
            Regex::new(r"^argocd\s+app\s+\w+\s+/argocd/").unwrap(),
            // HTTP clients with URLs (curl, wget, http)
            // These tools accept URLs that start with / but are not filesystem paths
            Regex::new(r"^(curl|wget|http)\s+.*https?://").unwrap(),
            // Nushell http commands
            // Matches: http get/post/... <url>
            Regex::new(r"^http\s+(get|post|put|delete|patch|head|options)\s+").unwrap(),
        ]
    })
}

/// Check if a command matches a safe pattern and should bypass path validation
fn matches_safe_pattern(command: &str) -> bool {
    get_safe_command_patterns()
        .iter()
        .any(|pattern| pattern.is_match(command))
}

/// Manually resolve a relative path with .. components
/// Returns the resolved path
fn resolve_relative_path(base: &Path, relative: &str) -> Option<PathBuf> {
    let mut result = PathBuf::from(base);

    // Process each component of the relative path
    for part in relative.split('/') {
        match part {
            "" | "." => {
                // Empty or current directory - do nothing
            }
            ".." => {
                // Parent directory - pop
                result.pop();
            }
            _ => {
                // Regular component - push
                result.push(part);
            }
        }
    }

    Some(result)
}

/// Extract words from a command that are NOT inside quotes.
/// This handles Nushell's quoting rules including:
/// - Single quotes: 'text'
/// - Double quotes: "text"
/// - Backticks: `text`
/// - String interpolation: $"text" and $'text'
/// Multiline strings are properly handled (newlines inside quotes are treated as content)
fn extract_non_quoted_words(command: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut current_word = String::new();
    let mut quote_char: Option<char> = None;
    let mut prev_char: Option<char> = None;

    for ch in command.chars() {
        match (quote_char, ch) {
            // Not in quotes, hit a quote character (except $ before quote)
            (None, '\'' | '"' | '`') if prev_char != Some('$') => {
                quote_char = Some(ch);
            }
            // Not in quotes, hit $" or $' (string interpolation)
            (None, '"' | '\'') if prev_char == Some('$') => {
                quote_char = Some(ch);
            }
            // In quotes, hit matching close quote (not escaped)
            (Some(q), ch) if ch == q && prev_char != Some('\\') => {
                quote_char = None;
            }
            // In quotes - skip everything (including newlines!)
            (Some(_), _) => {}
            // Not in quotes, hit whitespace (including newlines)
            (None, ' ' | '\t' | '\n' | '\r') => {
                if !current_word.is_empty() {
                    words.push(current_word.clone());
                    current_word.clear();
                }
            }
            // Not in quotes, regular character
            (None, ch) => {
                current_word.push(ch);
            }
        }
        prev_char = Some(ch);
    }

    if !current_word.is_empty() {
        words.push(current_word);
    }

    words
}

/// Check if a word is a URL (has a protocol scheme)
fn is_url(word: &str) -> bool {
    word.starts_with("http://")
        || word.starts_with("https://")
        || word.starts_with("ftp://")
        || word.starts_with("ftps://")
        || word.starts_with("file://")
        || word.starts_with("ssh://")
        || word.starts_with("git://")
}

/// Check if a word is likely a filesystem path that should be validated
fn is_likely_filesystem_path(word: &str) -> bool {
    // Windows drive letter path (e.g., C:\path)
    if word.len() >= 3 && word.chars().nth(1) == Some(':') && word.contains('\\') {
        return true;
    }

    // Unix absolute path starting with /
    if word.starts_with('/') {
        // Exclude things that are clearly not filesystem paths

        // Has = sign before the slash (likely an option like --format=/path)
        if let Some(eq_pos) = word.find('=') {
            if let Some(slash_pos) = word.find('/') {
                if eq_pos < slash_pos {
                    // This is an option assignment, not a path
                    return false;
                }
            }
        }

        // Multiple consecutive slashes (likely URL or other non-path)
        if word.contains("//") {
            return false;
        }

        return true;
    }

    false
}

pub fn validate_path_safety(command: &str, sandbox_dir: &Path) -> Result<(), String> {
    // Check if command matches a safe pattern (commands with path-like args that aren't filesystem paths)
    // Examples: gh api /repos/..., kubectl get /apis/..., etc.
    if matches_safe_pattern(command) {
        return Ok(());
    }

    // Get canonical sandbox directory (only if it exists, otherwise skip validation)
    let canonical_sandbox = match sandbox_dir.canonicalize() {
        Ok(path) => path,
        Err(_) => {
            // If sandbox directory doesn't exist, we can't validate paths, so allow the command
            return Ok(());
        }
    };

    // Extract non-quoted words (respects Nushell quoting, including multiline strings)
    let words = extract_non_quoted_words(command);

    // Check if command contains absolute paths or home directory paths that would escape the sandbox
    for word in words {
        // Skip common commands and flags - only check things that look like paths
        if word.starts_with('-') || is_common_command(&word) {
            continue;
        }

        // Skip URLs - they're not filesystem paths
        if is_url(&word) {
            continue;
        }

        // Determine the path to check based on word type
        let path_to_check = if word == "~" || word.starts_with("~/") {
            // Home directory paths
            if let Some(home_dir) = std::env::var_os("HOME") {
                if word == "~" {
                    Path::new(&home_dir).to_path_buf()
                } else {
                    Path::new(&home_dir).join(&word[2..])
                }
            } else {
                continue; // Skip if HOME is not set
            }
        } else if word.contains("..") {
            // Path with traversal - resolve relative to sandbox directory
            // This allows cd ../ when inside the sandbox, but blocks escaping
            sandbox_dir.join(&word)
        } else if is_likely_filesystem_path(&word) {
            // Absolute path
            Path::new(&word).to_path_buf()
        } else if word.contains('/') || word.contains('\\') {
            // Relative path with slashes (e.g., "subdir/file.txt")
            sandbox_dir.join(&word)
        } else {
            // Plain word without path separators - not a path, skip
            continue;
        };

        // For paths with .., we need to check the resolved canonical path
        if word.contains("..") {
            // Resolve the path (handles .. components)
            // If the path doesn't exist, canonicalize will fail, so we manually resolve
            match path_to_check.canonicalize() {
                Ok(canonical_path) => {
                    // Path exists - check if it's within sandbox
                    if !canonical_path.starts_with(&canonical_sandbox) {
                        return Err(format!("Path '{}' would escape sandbox directory", &word));
                    }
                }
                Err(_) => {
                    // Path doesn't exist - manually check if resolved path stays in sandbox
                    // Use a simple component-based resolution
                    if let Some(resolved) = resolve_relative_path(sandbox_dir, &word) {
                        // Normalize the resolved path for comparison
                        // Since canonicalize failed (path doesn't exist), we compare the constructed path
                        if !resolved.starts_with(&canonical_sandbox) {
                            return Err(format!(
                                "Path '{}' would escape sandbox directory (resolved to {})",
                                &word,
                                resolved.display()
                            ));
                        }
                    }
                    // If we can't resolve, be conservative and allow it
                    // (nushell will handle the actual path resolution and fail if invalid)
                }
            }
        } else {
            // For existing paths without .., check if they're within sandbox
            if let Ok(canonical_path) = path_to_check.canonicalize() {
                if !canonical_path.starts_with(&canonical_sandbox) {
                    return Err(format!("Path '{}' escapes sandbox directory", &word));
                }
            } else if path_to_check.is_absolute() {
                // For non-existent absolute paths, check if they would be inside sandbox
                if !path_to_check.starts_with(&canonical_sandbox) {
                    return Err(format!("Path '{}' escapes sandbox directory", &word));
                }
            }
        }
    }

    Ok(())
}

fn is_common_command(word: &str) -> bool {
    matches!(
        word,
        "ls" | "cat"
            | "echo"
            | "pwd"
            | "cd"
            | "mkdir"
            | "rm"
            | "cp"
            | "mv"
            | "chmod"
            | "chown"
            | "grep"
            | "find"
            | "which"
            | "whoami"
            | "date"
            | "ps"
            | "top"
            | "kill"
            | "touch"
            | "head"
            | "tail"
            | "sort"
            | "uniq"
            | "wc"
            | "cut"
            | "awk"
            | "sed"
            | "tar"
            | "zip"
            | "unzip"
            | "curl"
            | "wget"
            | "git"
            | "npm"
            | "cargo"
            | "docker"
            | "python"
            | "node"
            | "java"
            | "version"
    )
}

#[cfg(test)]
mod mod_test;
