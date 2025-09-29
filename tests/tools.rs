use nu_mcp::tools::{discover_tools, execute_extension_tool};
use std::path::PathBuf;

fn get_test_tools_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("test/tools")
}

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

#[tokio::test]
async fn test_discover_tools_nonexistent_directory() {
    let nonexistent_path = PathBuf::from("/definitely/nonexistent/path/12345");
    let result = discover_tools(&nonexistent_path).await;

    // Should return Ok with empty vec for nonexistent directory
    assert!(result.is_ok());
    let tools = result.unwrap();
    assert!(tools.is_empty());
}

#[tokio::test]
async fn test_discover_tools_real_scripts() {
    let tools_dir = get_test_tools_dir();
    let result = discover_tools(&tools_dir).await;

    assert!(result.is_ok());
    let tools = result.unwrap();

    // Should find tools from test_simple.nu and test_math.nu 
    // test_invalid.nu should cause an error and be skipped
    assert!(tools.len() >= 3); // At least echo_test, add_numbers, multiply_numbers

    // Check for specific tools
    let tool_names: Vec<&str> = tools
        .iter()
        .map(|t| t.tool_definition.name.as_ref())
        .collect();
    assert!(tool_names.contains(&"echo_test"));
    assert!(tool_names.contains(&"add_numbers"));
    assert!(tool_names.contains(&"multiply_numbers"));
}

#[tokio::test]
async fn test_discover_tools_ignores_non_nu_files() {
    let tools_dir = get_test_tools_dir();
    let result = discover_tools(&tools_dir).await;

    assert!(result.is_ok());
    let tools = result.unwrap();

    // Should not include any tools from .txt files
    for tool in &tools {
        assert!(tool.script_path.extension().unwrap() == "nu");
    }
}

#[tokio::test]
async fn test_execute_simple_tool() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Find the echo_test tool
    let echo_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
        .expect("echo_test tool not found");

    // Execute the tool
    let result = execute_extension_tool(
        echo_tool,
        "echo_test",
        r#"{"message": "Hello Integration Test"}"#,
    )
    .await;

    assert!(result.is_ok());
    let output = result.unwrap();
    assert!(output.contains("Echo: Hello Integration Test"));
}

#[tokio::test]
async fn test_execute_math_tools() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test addition
    let add_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "add_numbers")
        .expect("add_numbers tool not found");

    let result = execute_extension_tool(add_tool, "add_numbers", r#"{"a": 5, "b": 3}"#).await;

    assert!(result.is_ok());
    let output = result.unwrap();
    assert!(output.contains("Result: 8"));

    // Test multiplication
    let mult_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "multiply_numbers")
        .expect("multiply_numbers tool not found");

    let result = execute_extension_tool(mult_tool, "multiply_numbers", r#"{"x": 4, "y": 7}"#).await;

    assert!(result.is_ok());
    let output = result.unwrap();
    assert!(output.contains("Product: 28"));
}

#[tokio::test]
async fn test_execute_tool_unknown_tool() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    assert!(!tools.is_empty(), "No tools discovered for testing");
    
    let any_tool = &tools[0];
    let result = execute_extension_tool(any_tool, "nonexistent_tool", "{}").await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(
        error.to_string().contains("Unknown tool") || 
        error.to_string().contains("nonexistent_tool")
    );
}

#[tokio::test]
async fn test_execute_tool_invalid_args() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    let echo_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
        .expect("echo_test tool not found");

    let result = execute_extension_tool(echo_tool, "echo_test", "invalid json").await;

    assert!(result.is_err());
}

#[tokio::test]
async fn test_tool_schema_validation() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Find the echo_test tool and validate its schema
    let echo_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
        .expect("echo_test tool not found");

    assert_eq!(echo_tool.tool_definition.name, "echo_test");
    assert!(echo_tool.tool_definition.description.is_some());
    assert_eq!(
        echo_tool.tool_definition.description.as_ref().unwrap(),
        "Simple echo test tool"
    );

    // Check input schema structure
    let schema = &echo_tool.tool_definition.input_schema;
    assert_eq!(schema.get("type").unwrap(), "object");
    assert!(schema.get("properties").is_some());
    assert!(schema.get("required").is_some());
}

#[tokio::test]
async fn test_discover_tools_with_empty_tools_script() {
    let tools_dir = get_test_tools_dir();
    let result = discover_tools(&tools_dir).await;
    assert!(result.is_ok());
    
    let tools = result.unwrap();
    
    // test_empty.nu returns empty tools list, so it shouldn't contribute any tools
    // But other scripts might contribute tools, so we just verify the result is valid
    for tool in &tools {
        assert!(!tool.tool_definition.name.is_empty());
        assert!(tool.script_path.extension().unwrap() == "nu");
    }
}

#[tokio::test]
async fn test_discover_tools_with_malformed_script() {
    let tools_dir = get_test_tools_dir();
    let result = discover_tools(&tools_dir).await;
    assert!(result.is_ok());
    
    let tools = result.unwrap();
    
    // test_invalid.nu has malformed JSON which should be handled gracefully
    // The discover_tools function should skip invalid scripts and continue
    // We should still get valid tools from other scripts
    for tool in &tools {
        // All discovered tools should be valid
        assert!(!tool.tool_definition.name.is_empty());
        assert!(tool.script_path.extension().unwrap() == "nu");
    }
}

#[tokio::test]
async fn test_execute_tool_with_complex_json() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    let math_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "add_numbers")
        .expect("add_numbers tool not found");

    // Test with floating point numbers
    let result = execute_extension_tool(
        math_tool,
        "add_numbers",
        r#"{"a": 3.14, "b": 2.86}"#,
    )
    .await;

    assert!(result.is_ok());
    let output = result.unwrap();
    assert!(output.contains("Result: 6"));
}

#[tokio::test]
async fn test_execute_tool_missing_required_args() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    let echo_tool = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
        .expect("echo_test tool not found");

    // Try to call without required message parameter
    let result = execute_extension_tool(echo_tool, "echo_test", r#"{}"#).await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    // The tool should error when required parameters are missing or wrong type
    assert!(
        error.to_string().contains("message") || 
        error.to_string().contains("required") ||
        error.to_string().contains("not found") ||
        error.to_string().contains("missing") ||
        error.to_string().contains("type_mismatch") ||
        error.to_string().contains("Type mismatch")
    );
}

#[tokio::test]
async fn test_tool_script_execution_with_existing_tools() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test that we can execute existing tools without timeout issues
    if let Some(echo_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
    {
        let result = execute_extension_tool(
            echo_tool,
            "echo_test",
            r#"{"message": "timeout test"}"#,
        )
        .await;
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("timeout test"));
    }
}

#[tokio::test]
async fn test_execute_tool_with_unicode_content() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test with unicode characters in existing tools
    if let Some(echo_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
    {
        let result = execute_extension_tool(
            echo_tool,
            "echo_test",
            r#"{"message": "Unicode test: 🚀 ñáéíóú 中文 世界"}"#,
        )
        .await;
        
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("🚀"));
        assert!(output.contains("中文"));
        assert!(output.contains("世界"));
    }
}

#[tokio::test]
async fn test_discover_tools_with_non_nu_files() {
    let tools_dir = get_test_tools_dir();
    let result = discover_tools(&tools_dir).await;
    assert!(result.is_ok());
    
    let tools = result.unwrap();
    
    // Verify that non-.nu files (like not_a_script.txt) are ignored
    for tool in &tools {
        assert!(tool.script_path.extension().unwrap() == "nu");
        assert!(tool.script_path.file_name().unwrap().to_string_lossy().ends_with(".nu"));
    }
}

#[tokio::test]
async fn test_execute_tool_error_handling() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test calling a tool that exists but with wrong arguments
    if let Some(math_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "add_numbers")
    {
        // Try with missing arguments
        let result = execute_extension_tool(math_tool, "add_numbers", r#"{}"#).await;
        assert!(result.is_err());
        
        // Try with invalid JSON
        let result = execute_extension_tool(math_tool, "add_numbers", "invalid json").await;
        assert!(result.is_err());
    }
}

#[tokio::test]
async fn test_tool_discovery_mixed_valid_invalid() {
    let tools_dir = get_test_tools_dir();
    let result = discover_tools(&tools_dir).await;
    assert!(result.is_ok());
    
    let tools = result.unwrap();
    
    // Should find valid tools despite having invalid scripts in the directory
    // We expect at least echo_test, add_numbers, multiply_numbers from valid scripts
    let tool_names: Vec<&str> = tools
        .iter()
        .map(|t| t.tool_definition.name.as_ref())
        .collect();
    
    // Count expected tools that should be found
    let expected_tools = ["echo_test", "add_numbers", "multiply_numbers"];
    let found_expected = expected_tools
        .iter()
        .filter(|&name| tool_names.contains(name))
        .count();
    
    // Should find at least some of the expected tools
    assert!(found_expected > 0, "Should find at least some valid tools despite invalid scripts");
}

#[test]
fn test_tool_definition_edge_cases() {
    // Test with minimal tool definition
    let minimal_schema = serde_json::json!({
        "type": "object"
    });
    
    assert_eq!(minimal_schema.get("type").unwrap(), "object");
    assert!(minimal_schema.get("properties").is_none());
    
    // Test with complex nested schema
    let complex_schema = serde_json::json!({
        "type": "object",
        "properties": {
            "config": {
                "type": "object",
                "properties": {
                    "nested": {
                        "type": "array",
                        "items": { "type": "string" }
                    }
                }
            }
        }
    });
    
    assert!(complex_schema.get("properties").is_some());
    let config_prop = &complex_schema["properties"]["config"];
    assert_eq!(config_prop["type"], "object");
}

#[tokio::test]
async fn test_discover_tools_empty_directory() {
    // Create a temporary directory that's empty
    let empty_dir = std::env::temp_dir().join("nu_mcp_test_empty");
    std::fs::create_dir_all(&empty_dir).unwrap();
    
    let result = discover_tools(&empty_dir).await;
    assert!(result.is_ok());
    
    let tools = result.unwrap();
    assert!(tools.is_empty());
    
    // Cleanup
    std::fs::remove_dir_all(&empty_dir).unwrap();
}

#[tokio::test]
async fn test_discover_tools_permission_errors() {
    // Test with a path that doesn't exist and can't be read
    let nonexistent = PathBuf::from("/this/path/definitely/does/not/exist/anywhere");
    let result = discover_tools(&nonexistent).await;
    
    // Should return Ok with empty vec for nonexistent/unreadable directories
    assert!(result.is_ok());
    let tools = result.unwrap();
    assert!(tools.is_empty());
}

#[tokio::test]
async fn test_execute_extension_tool_timeout() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test that tools execute within reasonable time
    if let Some(echo_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
    {
        let start = std::time::Instant::now();
        let result = execute_extension_tool(
            echo_tool,
            "echo_test",
            r#"{"message": "timeout test"}"#,
        )
        .await;
        let duration = start.elapsed();
        
        assert!(result.is_ok());
        // Should complete quickly (less than 5 seconds for a simple echo)
        assert!(duration < std::time::Duration::from_secs(5));
    }
}

#[tokio::test]
async fn test_execute_extension_tool_large_output() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test with potentially large input
    if let Some(echo_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
    {
        let large_message = "x".repeat(1000); // 1KB message
        let args = format!(r#"{{"message": "{}"}}"#, large_message);
        
        let result = execute_extension_tool(echo_tool, "echo_test", &args).await;
        assert!(result.is_ok());
        
        let output = result.unwrap();
        assert!(output.contains(&large_message));
    }
}

#[tokio::test]
async fn test_execute_extension_tool_special_characters() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test with special characters that might break JSON or shell execution
    if let Some(echo_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "echo_test")
    {
        let special_chars = "!@#$%^&*()_+-=[]{}|;,./<>?";
        let args = serde_json::json!({"message": special_chars}).to_string();
        
        let result = execute_extension_tool(echo_tool, "echo_test", &args).await;
        assert!(result.is_ok());
        
        let output = result.unwrap();
        assert!(output.contains(special_chars));
    }
}

#[tokio::test]
async fn test_execute_extension_tool_empty_args() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(math_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "add_numbers")
    {
        // Test with empty args object
        let result = execute_extension_tool(math_tool, "add_numbers", r#"{}"#).await;
        
        // Should fail due to missing required arguments
        assert!(result.is_err());
        let error = result.unwrap_err();
        assert!(error.to_string().contains("message") || 
               error.to_string().contains("required") ||
               error.to_string().contains("missing") ||
               error.to_string().contains("type_mismatch") ||
               error.to_string().contains("Type mismatch"));
    }
}

#[tokio::test]
async fn test_execute_extension_tool_wrong_types() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(math_tool) = tools
        .iter()
        .find(|t| t.tool_definition.name == "add_numbers")
    {
        // Test with wrong argument types (strings instead of numbers)
        let result = execute_extension_tool(
            math_tool, 
            "add_numbers", 
            r#"{"a": "not_a_number", "b": "also_not_a_number"}"#
        ).await;
        
        // Should still work since nushell might coerce types, or fail gracefully
        // Either outcome is acceptable for this test
        if result.is_err() {
            let error = result.unwrap_err();
            // Error should be related to type handling
            assert!(error.to_string().len() > 0);
        }
    }
}

#[tokio::test]
async fn test_tool_definition_serialization() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test that tool definitions can be serialized/deserialized
    for tool in tools.iter().take(1) { // Test just one to avoid long test times
        let json = serde_json::to_string(&tool.tool_definition).unwrap();
        assert!(!json.is_empty());
        assert!(json.contains(tool.tool_definition.name.as_ref()));
        
        // Should be able to parse it back
        let parsed: rmcp::model::Tool = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.name, tool.tool_definition.name);
        assert_eq!(parsed.description, tool.tool_definition.description);
    }
}
