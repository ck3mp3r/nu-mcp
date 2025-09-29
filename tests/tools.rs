use std::path::PathBuf;

#[test]
fn test_path_operations() {
    let script_path = PathBuf::from("/test/path.nu");

    assert_eq!(script_path.extension().unwrap(), "nu");
    assert_eq!(script_path.file_stem().unwrap(), "path");

    let parent = script_path.parent().unwrap();
    assert_eq!(parent, PathBuf::from("/test"));
}

#[test]
fn test_path_validation() {
    let valid_nu_path = PathBuf::from("weather.nu");
    let invalid_path = PathBuf::from("script.sh");
    let no_extension = PathBuf::from("README");

    assert_eq!(
        valid_nu_path.extension().and_then(|s| s.to_str()),
        Some("nu")
    );
    assert_eq!(
        invalid_path.extension().and_then(|s| s.to_str()),
        Some("sh")
    );
    assert_eq!(no_extension.extension().and_then(|s| s.to_str()), None);
}

// Test behavior for nonexistent directory
#[tokio::test]
async fn test_discover_tools_nonexistent_directory() {
    use nu_mcp::tools::discover_tools;

    let nonexistent_path = PathBuf::from("/definitely/nonexistent/path/12345");
    let result = discover_tools(&nonexistent_path).await;

    // Should return Ok with empty vec for nonexistent directory
    assert!(result.is_ok());
    let tools = result.unwrap();
    assert!(tools.is_empty());
}
