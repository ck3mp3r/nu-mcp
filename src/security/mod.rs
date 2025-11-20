use std::path::Path;

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
    // Only check for path traversal patterns
    if command.contains("../")
        || command.contains("..\\")
        || command.contains(".. ")
        || command.contains(" ..")
    {
        return Err("Path traversal patterns (../) are not allowed".to_string());
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

        // Expand home directory paths to absolute paths
        let path_to_check = if word == "~" || word.starts_with("~/") {
            if let Some(home_dir) = std::env::var_os("HOME") {
                if word == "~" {
                    Path::new(&home_dir).to_path_buf()
                } else {
                    Path::new(&home_dir).join(&word[2..])
                }
            } else {
                continue; // Skip if HOME is not set
            }
        } else if is_likely_filesystem_path(&word) {
            Path::new(&word).to_path_buf()
        } else {
            continue; // Not an absolute or home directory path
        };

        // For existing paths, check if they're within sandbox
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
