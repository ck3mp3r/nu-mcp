use super::*;

#[test]
fn test_determine_working_directory_returns_current_dir_when_in_sandbox() {
    // If current directory IS in a sandbox, it should return current directory
    let cwd = env::current_dir().unwrap();

    // Use the actual current directory as one of the sandboxes
    let sandboxes = vec![cwd.clone()];
    let result = determine_working_directory(&sandboxes);
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), cwd);
}

#[test]
fn test_determine_working_directory_skips_invalid_sandboxes() {
    // Should skip invalid sandbox paths and check remaining valid ones
    let sandboxes = vec![
        PathBuf::from("/nonexistent/path/that/does/not/exist"),
        PathBuf::from("/another/invalid/path"),
        PathBuf::from("/tmp"),
    ];

    let result = determine_working_directory(&sandboxes);

    let cwd = env::current_dir().unwrap();
    if cwd.starts_with("/tmp") || cwd.starts_with("/private/tmp") {
        // If we're in /tmp, should succeed
        assert!(result.is_ok());
    } else {
        // If not in /tmp, should error since other sandboxes are invalid
        assert!(result.is_err());
        assert!(
            result
                .unwrap_err()
                .contains("Current directory could not be determined")
        );
    }
}

#[test]
fn test_determine_working_directory_with_empty_sandboxes() {
    let sandboxes: Vec<PathBuf> = vec![];

    let result = determine_working_directory(&sandboxes);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("No sandbox directories"));
}

#[test]
fn test_determine_working_directory_with_additional_sandboxes() {
    // Current directory PLUS additional sandboxes (realistic scenario from main.rs)
    let cwd = env::current_dir().unwrap();
    let sandboxes = vec![
        cwd.clone(),
        PathBuf::from("/tmp"),
        PathBuf::from("/nix/store"),
    ];

    let result = determine_working_directory(&sandboxes);
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), cwd);
}
