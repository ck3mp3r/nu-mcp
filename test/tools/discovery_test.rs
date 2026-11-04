use std::path::PathBuf;

use super::discover_tools;

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

fn get_test_tools_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("test/tools")
}

#[tokio::test]
async fn test_discover_tools_nonexistent_directory() -> Result<()> {
    let nonexistent_path = PathBuf::from("/definitely/nonexistent/path/12345");
    let result = discover_tools(&nonexistent_path).await;

    // Should return Ok with empty vec for nonexistent directory
    assert!(result.is_ok());
    let tools = result?;
    assert!(tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_real_scripts() -> Result<()> {
    let test_tools_dir = get_test_tools_dir();
    let result = discover_tools(&test_tools_dir).await;

    assert!(result.is_ok());
    let tools = result?;

    // Should discover some tools from the test directory
    assert!(!tools.is_empty());

    // Check that discovered tools have proper structure
    for tool in &tools {
        assert!(!tool.tool_definition.name.is_empty());
        assert!(tool.module_path.exists());
    }
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_ignores_non_nu_files() -> Result<()> {
    let test_tools_dir = get_test_tools_dir();
    let result = discover_tools(&test_tools_dir).await;

    assert!(result.is_ok());
    let tools = result?;

    // Verify that only .nu files are processed
    for tool in &tools {
        let mod_file = tool.module_path.join("mod.nu");
        assert!(mod_file.exists());
        assert_eq!(mod_file.extension().ok_or("extension should be set")?, "nu");
    }
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_with_empty_tools_script() -> Result<()> {
    // Test with empty directory that has no valid tools
    let test_tools_dir = get_test_tools_dir().join("empty");
    let result = discover_tools(&test_tools_dir).await;

    assert!(result.is_ok());
    let tools = result?;

    // Empty directory should return empty tools list
    assert!(tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_with_malformed_script() -> Result<()> {
    // Test with directory that has malformed scripts
    let test_tools_dir = get_test_tools_dir().join("invalid");
    let result = discover_tools(&test_tools_dir).await;

    // Should handle malformed scripts gracefully - function shouldn't crash
    assert!(
        result.is_ok(),
        "discover_tools should handle malformed scripts without panicking"
    );
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_with_non_nu_files() -> Result<()> {
    let test_tools_dir = get_test_tools_dir().join("no-mod-file");
    let result = discover_tools(&test_tools_dir).await;

    assert!(result.is_ok());
    let tools = result?;

    // Directory without mod.nu files should return empty
    assert!(tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_tool_discovery_mixed_valid_invalid() -> Result<()> {
    let test_tools_dir = get_test_tools_dir();
    let result = discover_tools(&test_tools_dir).await;

    assert!(result.is_ok());
    let tools = result?;

    // Should discover at least some valid tools despite invalid ones
    let valid_tools: Vec<_> = tools
        .iter()
        .filter(|t| !t.tool_definition.name.is_empty())
        .collect();
    assert!(!valid_tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_empty_directory() -> Result<()> {
    let test_tools_dir = get_test_tools_dir().join("empty");
    let result = discover_tools(&test_tools_dir).await;

    assert!(result.is_ok());
    let tools = result?;
    assert!(tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_permission_errors() -> Result<()> {
    // Test with directory that might have permission issues
    let restricted_path = PathBuf::from("/root/secret");
    let result = discover_tools(&restricted_path).await;

    // Should handle permission errors gracefully
    assert!(result.is_ok());
    let tools = result?;
    assert!(tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_script_execution_failure() -> Result<()> {
    // Test with scripts that fail during execution
    let test_tools_dir = get_test_tools_dir().join("invalid");
    let result = discover_tools(&test_tools_dir).await;

    // Should handle script execution failures gracefully
    assert!(result.is_ok());
    let _tools = result?;
    // Function should not panic or return error for script failures
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_from_directory_read_error() -> Result<()> {
    // Test with path that exists but can't be read as directory
    let file_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("Cargo.toml");
    let result = discover_tools(&file_path).await;

    // Should handle read errors gracefully
    assert!(result.is_ok());
    let tools = result?;
    assert!(tools.is_empty());
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_json_parse_error() -> Result<()> {
    // Test with scripts that return invalid JSON
    let test_tools_dir = get_test_tools_dir().join("invalid");
    let result = discover_tools(&test_tools_dir).await;

    // Should handle JSON parse errors gracefully
    assert!(result.is_ok());
    let _tools = result?;
    // Function should handle malformed JSON without crashing
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_direct_module_directory() -> Result<()> {
    // Test discovery when pointed directly at a module directory
    let simple_module = get_test_tools_dir().join("simple");
    let result = discover_tools(&simple_module).await;

    assert!(result.is_ok());
    let tools = result?;

    // When pointed at a module directory, should discover that module
    if simple_module.join("mod.nu").exists() {
        assert!(!tools.is_empty());
    }
    Ok(())
}

#[tokio::test]
async fn test_discover_tools_direct_module_vs_parent_directory() -> Result<()> {
    // Test the difference between pointing at a module vs its parent
    let tools_dir = get_test_tools_dir();
    let simple_module = tools_dir.join("simple");

    let parent_result = discover_tools(&tools_dir).await;
    let direct_result = discover_tools(&simple_module).await;

    assert!(parent_result.is_ok());
    assert!(direct_result.is_ok());

    let parent_tools = parent_result?;
    let direct_tools = direct_result?;

    // Parent directory should discover multiple modules
    // Direct module should discover just that one (if it exists)
    if simple_module.join("mod.nu").exists() {
        assert!(parent_tools.len() >= direct_tools.len());
    }
    Ok(())
}
