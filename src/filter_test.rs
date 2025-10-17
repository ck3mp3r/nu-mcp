use crate::filter::validate_path_safety;
use std::path::Path;

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
    let sandbox_dir = std::env::current_dir().unwrap();
    let sandbox_subdir = sandbox_dir.join("subdir");
    // This should be allowed as it's within the sandbox
    assert!(
        validate_path_safety(&format!("ls {}", sandbox_subdir.display()), &sandbox_dir).is_ok()
    );
}

#[test]
fn test_absolute_paths_outside_sandbox_blocked() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = std::env::current_dir().unwrap();
    // These should be blocked as they escape the sandbox
    assert!(validate_path_safety("ls /etc/passwd", &sandbox_dir).is_err());
    assert!(validate_path_safety("cat /tmp/other", &sandbox_dir).is_err());
}
