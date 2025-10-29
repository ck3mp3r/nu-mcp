use std::path::Path;

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

    // Check if command contains absolute paths or home directory paths that would escape the sandbox
    for word in command.split_whitespace() {
        // Skip common commands and flags - only check things that look like paths
        if word.starts_with('-') || is_common_command(word) {
            continue;
        }

        // Expand home directory paths to absolute paths
        let path_to_check = if word.starts_with("~/") {
            if let Some(home_dir) = std::env::var_os("HOME") {
                Path::new(&home_dir).join(&word[2..])
            } else {
                continue; // Skip if HOME is not set
            }
        } else if word.starts_with('/') || word.contains(":\\") {
            Path::new(word).to_path_buf()
        } else {
            continue; // Not an absolute or home directory path
        };

        // For existing paths, check if they're within sandbox
        if let Ok(canonical_path) = path_to_check.canonicalize() {
            if !canonical_path.starts_with(&canonical_sandbox) {
                return Err(format!("Path '{}' escapes sandbox directory", word));
            }
        } else if path_to_check.is_absolute() {
            // For non-existent absolute paths, check if they would be inside sandbox
            if !path_to_check.starts_with(&canonical_sandbox) {
                return Err(format!("Path '{}' escapes sandbox directory", word));
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
