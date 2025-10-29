use super::validate_path_safety;
use std::{env::current_dir, path::Path};

fn default_sandbox_dir() -> &'static Path {
    Path::new("/tmp/test_sandbox")
}

#[test]
fn test_path_traversal_blocked() {
    assert!(validate_path_safety("ls ../secret", default_sandbox_dir()).is_err());
    assert!(validate_path_safety("cd ..", default_sandbox_dir()).is_err());
    assert!(validate_path_safety("cat ../../etc/passwd", default_sandbox_dir()).is_err());
    assert!(validate_path_safety("ls ./../../secret", default_sandbox_dir()).is_err());
    assert!(validate_path_safety("cat ./../../../etc/passwd", default_sandbox_dir()).is_err());
}

#[test]
fn test_relative_paths_allowed() {
    assert!(validate_path_safety("ls ./foo-bar", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety("cat ./foo/bar", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety("cat foo/bar.txt", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety("echo hello", default_sandbox_dir()).is_ok());
}

#[test]
fn test_absolute_paths_in_sandbox_allowed() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = current_dir().unwrap();
    let sandbox_subdir = sandbox_dir.join("subdir");
    // This should be allowed as it's within the sandbox
    assert!(
        validate_path_safety(&format!("ls {}", sandbox_subdir.display()), &sandbox_dir).is_ok()
    );
}

#[test]
fn test_absolute_paths_outside_sandbox_blocked() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = current_dir().unwrap();
    // These should be blocked as they escape the sandbox
    assert!(validate_path_safety("ls /etc/passwd", &sandbox_dir).is_err());
    assert!(validate_path_safety("cat /tmp/other", &sandbox_dir).is_err());
}

#[test]
fn test_home_directory_paths_within_sandbox_allowed() {
    // Use the current directory as sandbox (it definitely exists)
    let sandbox_dir = current_dir().unwrap();

    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);

        // Only test if sandbox is within home directory
        if sandbox_dir.starts_with(home_path) {
            // Get the relative path from home to sandbox
            let relative = sandbox_dir.strip_prefix(home_path).unwrap();
            let home_prefix_path = format!("~/{}", relative.display());

            // Commands with home directory paths within the sandbox should be allowed
            let test_path = format!("ls {}/file.txt", home_prefix_path);
            assert!(
                validate_path_safety(&test_path, &sandbox_dir).is_ok(),
                "Home directory path within sandbox should be allowed"
            );

            let test_path2 = format!("cat {}/subdir/data.txt", home_prefix_path);
            assert!(
                validate_path_safety(&test_path2, &sandbox_dir).is_ok(),
                "Home directory subpath within sandbox should be allowed"
            );
        }
    }
}

#[test]
fn test_home_directory_paths_outside_sandbox_blocked() {
    // Use the current directory as sandbox (it definitely exists)
    let sandbox_dir = current_dir().unwrap();

    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);

        // Test paths that are definitely outside the sandbox
        // These should be blocked regardless of where sandbox is
        let test_path = format!("ls ~/.bashrc");
        let result = validate_path_safety(&test_path, &sandbox_dir);

        // Only assert if the file exists (so we can properly test)
        let bashrc_path = home_path.join(".bashrc");
        if bashrc_path.exists() {
            assert!(
                result.is_err(),
                "Home directory path to config files should be blocked"
            );
        }

        // Test with a path that definitely doesn't match sandbox
        let test_path2 = format!("cat ~/definitely_outside_sandbox_xyz123/file.txt");
        assert!(
            validate_path_safety(&test_path2, &sandbox_dir).is_err(),
            "Home directory path outside sandbox should be blocked"
        );
    }
}

#[test]
fn test_home_directory_paths_with_current_dir_sandbox() {
    // Use current directory as sandbox (not in home directory)
    let sandbox_dir = std::env::current_dir().unwrap();

    // If sandbox is not in home directory, all home directory paths should be blocked
    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);
        if !sandbox_dir.starts_with(home_path) {
            assert!(
                validate_path_safety("ls ~/file.txt", &sandbox_dir).is_err(),
                "Home directory paths should be blocked when sandbox is outside home"
            );
        }
    }
}

#[test]
fn test_tilde_alone_blocked_when_outside_sandbox() {
    // Use current directory as sandbox
    let sandbox_dir = std::env::current_dir().unwrap();

    // If sandbox is not in home directory, ~ alone should be blocked
    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);
        if !sandbox_dir.starts_with(home_path) {
            assert!(
                validate_path_safety("ls ~", &sandbox_dir).is_err(),
                "Tilde alone should be blocked when home is outside sandbox"
            );
            assert!(
                validate_path_safety("cd ~", &sandbox_dir).is_err(),
                "Tilde alone in cd command should be blocked"
            );
        }
    }
}

#[test]
fn test_tilde_alone_allowed_when_within_sandbox() {
    // Use current directory as sandbox
    let sandbox_dir = std::env::current_dir().unwrap();

    // If sandbox is in home directory, ~ alone should be allowed only if it points to sandbox or subdirectory
    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);
        if sandbox_dir == home_path {
            assert!(
                validate_path_safety("ls ~", &sandbox_dir).is_ok(),
                "Tilde alone should be allowed when sandbox is home directory itself"
            );
        }
    }
}
