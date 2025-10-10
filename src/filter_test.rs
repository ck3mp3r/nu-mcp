use crate::filter::validate_path_safety;
use std::path::Path;

fn default_jail_dir() -> &'static Path {
    Path::new("/tmp/test_jail")
}

#[test]
fn test_path_traversal_blocked() {
    assert!(validate_path_safety("ls ../secret", default_jail_dir()).is_err());
    assert!(validate_path_safety("cd ..", default_jail_dir()).is_err());
    assert!(validate_path_safety("cat ../../etc/passwd", default_jail_dir()).is_err());
    assert!(validate_path_safety("ls ./../../secret", default_jail_dir()).is_err());
    assert!(validate_path_safety("cat ./../../../etc/passwd", default_jail_dir()).is_err());
}

#[test]
fn test_relative_paths_allowed() {
    assert!(validate_path_safety("ls ./foo-bar", default_jail_dir()).is_ok());
    assert!(validate_path_safety("cat ./foo/bar", default_jail_dir()).is_ok());
    assert!(validate_path_safety("cat foo/bar.txt", default_jail_dir()).is_ok());
    assert!(validate_path_safety("echo hello", default_jail_dir()).is_ok());
}

#[test]
fn test_absolute_paths_in_jail_allowed() {
    // Use the current directory as jail for testing (it definitely exists)
    let jail_dir = std::env::current_dir().unwrap();
    let jail_subdir = jail_dir.join("subdir");
    // This should be allowed as it's within the jail
    assert!(validate_path_safety(&format!("ls {}", jail_subdir.display()), &jail_dir).is_ok());
}

#[test]
fn test_absolute_paths_outside_jail_blocked() {
    // Use the current directory as jail for testing (it definitely exists)
    let jail_dir = std::env::current_dir().unwrap();
    // These should be blocked as they escape the jail
    assert!(validate_path_safety("ls /etc/passwd", &jail_dir).is_err());
    assert!(validate_path_safety("cat /tmp/other", &jail_dir).is_err());
}
