use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Default)]
pub struct Config {
    pub tools_dir: Option<PathBuf>,
    pub enable_run_nushell: bool,
    pub jail_directory: Option<PathBuf>,
}

pub fn validate_path_safety(command: &str, jail_dir: &Path) -> Result<(), String> {
    // Only check for path traversal patterns - remove all other "security" checks
    if command.contains("../") || command.contains("..\\") || command.contains(".. ") || command.contains(" ..") {
        return Err("Path traversal patterns (../) are not allowed".to_string());
    }

    // Get canonical jail directory (only if it exists, otherwise skip validation)
    let canonical_jail = match jail_dir.canonicalize() {
        Ok(path) => path,
        Err(_) => {
            // If jail directory doesn't exist, we can't validate paths, so allow the command
            return Ok(());
        }
    };

    // Check if command contains absolute paths that would escape the jail
    for word in command.split_whitespace() {
        // Skip common commands and flags - only check things that look like paths
        if word.starts_with('-') || is_common_command(word) {
            continue;
        }
        
        if word.starts_with('/') || word.contains(":\\") {
            // For existing paths, check if they're within jail
            if let Ok(canonical_path) = Path::new(word).canonicalize() {
                if !canonical_path.starts_with(&canonical_jail) {
                    return Err(format!("Absolute path '{}' escapes jail directory", word));
                }
            } else if word.starts_with('/') {
                // For non-existent absolute paths, check if they would be inside jail
                let absolute_path = Path::new(word);
                if !absolute_path.starts_with(&canonical_jail) {
                    return Err(format!("Absolute path '{}' escapes jail directory", word));
                }
            }
        }
    }

    Ok(())
}

fn is_common_command(word: &str) -> bool {
    matches!(word, 
        "ls" | "cat" | "echo" | "pwd" | "cd" | "mkdir" | "rm" | "cp" | "mv" | 
        "chmod" | "chown" | "grep" | "find" | "which" | "whoami" | "date" | 
        "ps" | "top" | "kill" | "touch" | "head" | "tail" | "sort" | "uniq" |
        "wc" | "cut" | "awk" | "sed" | "tar" | "zip" | "unzip" | "curl" | "wget" |
        "git" | "npm" | "cargo" | "docker" | "python" | "node" | "java" | "version"
    )
}
