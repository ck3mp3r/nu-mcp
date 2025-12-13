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

/// Load safe command patterns from file at compile time
const SAFE_PATTERNS_FILE: &str = include_str!("safe_command_patterns.txt");

/// Parse pattern file and compile regexes
/// Lines starting with # are comments, empty lines are ignored
fn parse_pattern_file(content: &str) -> Vec<Regex> {
    content
        .lines()
        .map(|line| line.trim())
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(|pattern| {
            Regex::new(pattern)
                .unwrap_or_else(|e| panic!("Invalid regex pattern '{}': {}", pattern, e))
        })
        .collect()
}

/// Safe command patterns that bypass path validation
/// These patterns match commands that use path-like arguments but are NOT filesystem paths
/// Examples: API endpoints, resource identifiers, URL paths, etc.
///
/// Patterns are loaded from safe_command_patterns.txt at compile time
fn get_safe_command_patterns() -> &'static Vec<Regex> {
    static PATTERNS: OnceLock<Vec<Regex>> = OnceLock::new();
    PATTERNS.get_or_init(|| parse_pattern_file(SAFE_PATTERNS_FILE))
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

/// Check if a path is within any of the sandbox directories
fn is_path_in_any_sandbox(path: &Path, sandboxes: &[PathBuf]) -> bool {
    sandboxes.iter().any(|sandbox| path.starts_with(sandbox))
}

/// Format sandbox list for error messages
fn format_sandbox_list(sandboxes: &[PathBuf]) -> String {
    sandboxes
        .iter()
        .map(|d| d.display().to_string())
        .collect::<Vec<_>>()
        .join(", ")
}

/// Extract all words from a command by splitting on whitespace
/// NOTE: This does NOT skip quoted strings because quotes don't prevent filesystem access!
/// Commands like `cat "/etc/passwd"` will still read the file even though it's quoted.
fn extract_words(command: &str) -> Vec<String> {
    command
        .split_whitespace()
        .map(|s| {
            // Strip surrounding quotes to get the actual argument value
            let s = s.trim();
            let s = if (s.starts_with('"') && s.ends_with('"'))
                || (s.starts_with('\'') && s.ends_with('\''))
                || (s.starts_with('`') && s.ends_with('`'))
            {
                &s[1..s.len() - 1]
            } else {
                s
            };

            // Strip trailing shell metacharacters (;, &, |, etc.)
            let s = s.trim_end_matches([';', '&', '|', '>', '<']);
            s.to_string()
        })
        .collect()
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
        if let Some(eq_pos) = word.find('=')
            && let Some(slash_pos) = word.find('/')
            && eq_pos < slash_pos
        {
            // This is an option assignment, not a path
            return false;
        }

        // Multiple consecutive slashes (likely URL or other non-path)
        if word.contains("//") {
            return false;
        }

        return true;
    }

    false
}

pub fn validate_path_safety(
    command: &str,
    sandbox_dirs: &[std::path::PathBuf],
) -> Result<(), String> {
    // Check if command matches a safe pattern (commands with path-like args that aren't filesystem paths)
    // Examples: gh api /repos/..., kubectl get /apis/..., etc.
    if matches_safe_pattern(command) {
        return Ok(());
    }

    // Get canonical sandbox directories (only those that exist)
    let canonical_sandboxes: Vec<std::path::PathBuf> = sandbox_dirs
        .iter()
        .filter_map(|dir| dir.canonicalize().ok())
        .collect();

    // If no valid sandboxes, allow everything (shouldn't happen with defaults)
    if canonical_sandboxes.is_empty() {
        return Ok(());
    }

    // Get first sandbox for relative path resolution
    let first_sandbox = &canonical_sandboxes[0];

    // Extract all words from command (including quoted strings)
    let words = extract_words(command);

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
            // Path with traversal - resolve relative to first sandbox directory
            // This allows cd ../ when inside the sandbox, but blocks escaping
            first_sandbox.join(&word)
        } else if is_likely_filesystem_path(&word) {
            // Absolute path
            Path::new(&word).to_path_buf()
        } else if word.contains('/') || word.contains('\\') {
            // Relative path with slashes (e.g., "subdir/file.txt")
            first_sandbox.join(&word)
        } else {
            // Plain word without path separators - not a path, skip
            continue;
        };

        // Try to canonicalize the path if it exists, otherwise use manual resolution
        let canonical_path = match path_to_check.canonicalize() {
            Ok(canonical) => canonical,
            Err(_) if word.contains("..") => {
                // For non-existent paths with .., manually resolve components
                match resolve_relative_path(first_sandbox, &word) {
                    Some(resolved) => resolved,
                    None => continue, // Can't resolve, skip
                }
            }
            Err(_) if path_to_check.is_absolute() => {
                // Non-existent absolute path - use as-is for validation
                path_to_check
            }
            Err(_) => {
                // Non-existent relative path - skip validation (Nushell will handle)
                continue;
            }
        };

        // Check if the canonical/resolved path is within any sandbox
        if !is_path_in_any_sandbox(&canonical_path, &canonical_sandboxes) {
            return Err(format!(
                "Path '{}' escapes sandbox directories. Allowed: {}",
                &word,
                format_sandbox_list(&canonical_sandboxes)
            ));
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
