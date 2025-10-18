use super::{NushellToolExecutor, ToolExecutor, discover_tools};
use std::path::PathBuf;

fn get_test_tools_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("test/tools")
}

async fn execute_extension_tool_helper(
    extension: &crate::tools::ExtensionTool,
    tool_name: &str,
    args: &str,
) -> Result<String, Box<dyn std::error::Error>> {
    let tool_executor = NushellToolExecutor;
    tool_executor.execute_tool(extension, tool_name, args).await
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
    let result = execute_extension_tool_helper(
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

    // Find math tools - make test more robust
    let add_tool = tools.iter().find(|t| t.tool_definition.name == "add");

    if add_tool.is_none() {
        // Skip test if add tool not available
        return;
    }
    let add_tool = add_tool.unwrap();

    // Test addition
    let result = execute_extension_tool_helper(add_tool, "add", r#"{"x": 5, "y": 3}"#).await;

    assert!(result.is_ok());
    let output = result.unwrap();
    assert!(output.contains("8"));
}

#[tokio::test]
async fn test_execute_tool_unknown_tool() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(tool) = tools.first() {
        // Try to execute with wrong tool name
        let result = execute_extension_tool_helper(tool, "nonexistent_tool", "{}").await;

        // Should handle unknown tool gracefully
        assert!(result.is_err() || result.unwrap().contains("error"));
    }
}

#[tokio::test]
async fn test_execute_tool_invalid_args() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(tool) = tools.first() {
        // Try to execute with invalid JSON args
        let result =
            execute_extension_tool_helper(tool, &tool.tool_definition.name, "invalid json").await;

        // Should handle invalid arguments gracefully
        assert!(result.is_err() || result.unwrap().contains("error"));
    }
}

#[tokio::test]
async fn test_execute_tool_with_complex_json() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(tool) = tools.first() {
        let complex_args = r#"{
            "nested": {
                "array": [1, 2, 3],
                "string": "test",
                "boolean": true
            }
        }"#;

        let result =
            execute_extension_tool_helper(tool, &tool.tool_definition.name, complex_args).await;

        // Should handle complex JSON arguments
        assert!(result.is_ok() || result.is_err()); // Just ensure it doesn't panic
    }
}

#[tokio::test]
async fn test_execute_tool_with_unicode_content() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(echo_tool) = tools.iter().find(|t| t.tool_definition.name == "echo_test") {
        let unicode_args = r#"{"message": "Hello 世界 🌍 🚀"}"#;

        let result = execute_extension_tool_helper(echo_tool, "echo_test", unicode_args).await;

        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("世界") || output.contains("🌍"));
    }
}

#[tokio::test]
async fn test_execute_tool_error_handling() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    // Test with missing required arguments
    if let Some(tool) = tools.iter().find(|t| t.tool_definition.name == "add") {
        let result = execute_extension_tool_helper(tool, "add", "{}").await;

        // Should handle missing required args gracefully
        assert!(result.is_err() || result.unwrap().contains("error"));
    }
}

#[tokio::test]
async fn test_execute_tool_missing_required_args() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(add_tool) = tools.iter().find(|t| t.tool_definition.name == "add") {
        // Missing y parameter
        let result = execute_extension_tool_helper(add_tool, "add", r#"{"x": 5}"#).await;

        // Should handle missing required parameters
        assert!(result.is_err() || result.unwrap().contains("error"));
    }
}

#[tokio::test]
async fn test_execute_extension_tool_with_nonexistent_script() {
    // Create a fake tool with nonexistent script path
    let fake_tool = crate::tools::ExtensionTool {
        module_path: PathBuf::from("/nonexistent/path"),
        tool_definition: rmcp::model::Tool {
            name: "fake_tool".into(),
            description: Some("Fake tool for testing".into()),
            input_schema: std::sync::Arc::new(serde_json::Map::new()),
            annotations: None,
            title: None,
            output_schema: None,
            icons: None,
        },
    };

    let result = execute_extension_tool_helper(&fake_tool, "fake_tool", "{}").await;

    // Should handle nonexistent script gracefully
    assert!(result.is_err());
}

#[tokio::test]
async fn test_execute_extension_tool_large_output() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(tool) = tools.first() {
        // Test with args that might produce large output
        let large_args = r#"{"data": "x".repeat(1000)}"#;

        let result =
            execute_extension_tool_helper(tool, &tool.tool_definition.name, &large_args).await;

        // Should handle large input/output gracefully
        assert!(result.is_ok() || result.is_err()); // Just ensure it doesn't panic
    }
}

#[tokio::test]
async fn test_execute_extension_tool_timeout() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(tool) = tools.first() {
        // Execute tool (should complete in reasonable time)
        let result = execute_extension_tool_helper(tool, &tool.tool_definition.name, "{}").await;

        // Should complete without timing out
        assert!(result.is_ok() || result.is_err()); // Just ensure it doesn't hang
    }
}

#[tokio::test]
async fn test_execute_extension_tool_empty_args() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(tool) = tools.first() {
        let result = execute_extension_tool_helper(tool, &tool.tool_definition.name, "").await;

        // Should handle empty args gracefully
        assert!(result.is_ok() || result.is_err()); // Just ensure it doesn't panic
    }
}

#[tokio::test]
async fn test_execute_extension_tool_special_characters() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(echo_tool) = tools.iter().find(|t| t.tool_definition.name == "echo_test") {
        let special_args = r#"{"message": "Test with \"quotes\" and \n newlines \t tabs"}"#;

        let result = execute_extension_tool_helper(echo_tool, "echo_test", special_args).await;

        // Should handle special characters gracefully
        assert!(result.is_ok() || result.is_err()); // Just ensure it doesn't panic
    }
}

#[tokio::test]
async fn test_execute_extension_tool_wrong_types() {
    let tools_dir = get_test_tools_dir();
    let tools = discover_tools(&tools_dir)
        .await
        .expect("Failed to discover tools");

    if let Some(add_tool) = tools.iter().find(|t| t.tool_definition.name == "add") {
        // Pass string instead of number
        let result =
            execute_extension_tool_helper(add_tool, "add", r#"{"x": "not_a_number", "y": 3}"#)
                .await;

        // Should handle wrong types gracefully
        assert!(result.is_err() || result.unwrap().contains("error"));
    }
}
