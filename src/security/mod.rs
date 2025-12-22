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
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use tracing::{debug, trace};

/// Load safe command patterns from file at compile time
const SAFE_PATTERNS_FILE: &str = include_str!("safe_command_patterns.txt");

/// Path cache for remembering strings that look like paths but aren't filesystem paths
///
/// This cache stores path-like strings (starting with `/`) that don't exist on the
/// filesystem and are outside the sandbox. These are typically API endpoints or
/// other non-filesystem arguments.
///
/// # Examples
/// - `/metrics` - Kubernetes API endpoint
/// - `/api/v1/pods` - API path
/// - `/healthz` - Health check endpoint
///
/// # Lifecycle
/// - Session-scoped (in-memory)
/// - Cleared on server restart
/// - No TTL needed (sandbox dirs are static)
pub struct PathCache {
    /// Strings that look like paths but aren't filesystem paths
    not_filesystem_paths: HashSet<String>,
}

impl PathCache {
    /// Create a new empty cache
    pub fn new() -> Self {
        Self {
            not_filesystem_paths: HashSet::new(),
        }
    }

    /// Check if a path-like string is cached as "not a filesystem path"
    pub fn contains(&self, path: &str) -> bool {
        self.not_filesystem_paths.contains(path)
    }

    /// Remember that this string is not a filesystem path
    pub fn remember(&mut self, path: String) {
        self.not_filesystem_paths.insert(path);
    }

    /// Check if cache is empty
    pub fn is_empty(&self) -> bool {
        self.not_filesystem_paths.is_empty()
    }

    /// Get number of cached paths
    pub fn len(&self) -> usize {
        self.not_filesystem_paths.len()
    }
}

impl Default for PathCache {
    fn default() -> Self {
        Self::new()
    }
}

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

/// Validate path safety with caching support
///
/// This is the same as `validate_path_safety` but with an additional cache parameter
/// that remembers non-filesystem path-like strings to avoid repeated validation.
///
/// # Cache Behavior
/// - Checks cache first - if path is cached, skip all validation
/// - After sandbox check, caches non-existent paths outside sandbox
/// - Never caches paths inside sandbox (handled by sandbox check)
/// - Never caches existing files outside sandbox (blocked)
pub fn validate_path_safety_with_cache(
    command: &str,
    sandbox_dirs: &[std::path::PathBuf],
    cache: &mut PathCache,
) -> Result<(), String> {
    debug!(
        "validate_path_safety_with_cache called: command={:?}",
        command
    );

    // Check if command matches a safe pattern (commands with path-like args that aren't filesystem paths)
    // Examples: gh api /repos/..., kubectl get /apis/..., etc.
    if matches_safe_pattern(command) {
        debug!("Command matches safe pattern, allowing");
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
    debug!("Starting word-by-word validation loop");
    for word in words {
        trace!("Checking word: {:?}", word);

        // 1. CHECK CACHE FIRST - short circuit if we've seen this before
        if cache.contains(&word) {
            trace!("Cache hit for: {:?}, skipping validation", word);
            continue; // We know this isn't a filesystem path
        }

        // Skip common commands and flags - only check things that look like paths
        if word.starts_with('-') || is_common_command(&word) {
            trace!("Word is flag or common command, skipping: {:?}", word);
            continue;
        }

        // Skip URLs - they're not filesystem paths
        if is_url(&word) {
            trace!("Word is URL, skipping: {:?}", word);
            continue;
        }

        // Determine the path to check based on word type
        trace!("Determining path type for word: {:?}", word);
        let path_to_check = if word == "~" || word.starts_with("~/") {
            // Home directory paths
            trace!("Word is home directory path");
            if let Some(home_dir) = std::env::var_os("HOME") {
                if word == "~" {
                    Path::new(&home_dir).to_path_buf()
                } else {
                    Path::new(&home_dir).join(&word[2..])
                }
            } else {
                trace!("HOME not set, skipping");
                continue; // Skip if HOME is not set
            }
        } else if word.contains("..") {
            // Path with traversal - resolve relative to first sandbox directory
            // This allows cd ../ when inside the sandbox, but blocks escaping
            trace!("Word contains path traversal (..)");
            first_sandbox.join(&word)
        } else if is_likely_filesystem_path(&word) {
            // Absolute path
            trace!("Word is likely filesystem path");
            Path::new(&word).to_path_buf()
        } else if word.contains('/') || word.contains('\\') {
            // Relative path with slashes (e.g., "subdir/file.txt")
            trace!("Word is relative path with slashes");
            first_sandbox.join(&word)
        } else {
            // Plain word without path separators - not a path, skip
            trace!("Word is plain word, not a path, skipping");
            continue;
        };
        trace!("Path to check: {:?}", path_to_check);

        // Try to canonicalize the path if it exists, otherwise use manual resolution
        trace!("Attempting to canonicalize: {:?}", path_to_check);
        let canonical_path = match path_to_check.canonicalize() {
            Ok(canonical) => {
                trace!("Successfully canonicalized to: {:?}", canonical);
                canonical
            }
            Err(_) if word.contains("..") => {
                trace!("Canonicalization failed, manually resolving path with ..");
                // For non-existent paths with .., manually resolve components
                match resolve_relative_path(first_sandbox, &word) {
                    Some(resolved) => {
                        trace!("Manually resolved to: {:?}", resolved);
                        resolved
                    }
                    None => {
                        trace!("Manual resolution failed, skipping");
                        continue; // Can't resolve, skip
                    }
                }
            }
            Err(_) if path_to_check.is_absolute() => {
                trace!("Non-existent absolute path, using as-is");
                // Non-existent absolute path - use as-is for validation
                path_to_check
            }
            Err(_) => {
                trace!("Non-existent relative path, skipping validation");
                // Non-existent relative path - skip validation (Nushell will handle)
                continue;
            }
        };

        // 2. Check if the canonical/resolved path is within any sandbox
        trace!("Checking if path is in sandbox: {:?}", canonical_path);
        if is_path_in_any_sandbox(&canonical_path, &canonical_sandboxes) {
            trace!("Path is in sandbox, allowing");
            continue; // In sandbox - allow (don't cache, handled by sandbox check)
        }
        trace!("Path is outside sandbox");

        // 3. Path is outside sandbox - does it exist?
        trace!("Checking if path exists: {:?}", canonical_path);
        if !canonical_path.exists() {
            trace!(
                "Path does not exist, caching as non-filesystem path: {:?}",
                word
            );
            // Non-existent path outside sandbox - cache it as "not a filesystem path"
            cache.remember(word.clone());
            trace!("Successfully cached, continuing");
            continue; // Allow
        }

        // 4. Path exists AND outside sandbox - BLOCK
        debug!("Path exists outside sandbox, blocking: {:?}", word);
        return Err(format!(
            "Path '{}' escapes sandbox directories. Allowed: {}",
            &word,
            format_sandbox_list(&canonical_sandboxes)
        ));
    }

    debug!("All words validated successfully");
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
