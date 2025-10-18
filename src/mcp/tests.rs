use super::{NushellTool, ToolRouter, formatter::ResultFormatter};
use crate::config::Config;
use crate::execution::MockExecutor;
use crate::tools::MockToolExecutor;
use rmcp::handler::server::ServerHandler;
use rmcp::model::{CallToolRequestParam, Tool};
use rmcp::serde_json;
use std::path::PathBuf;
use std::sync::Arc;

#[test]
fn test_get_info_includes_sandbox_info() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directory: Some(PathBuf::from("/tmp/sandbox")),
    };
    let executor = Arc::new(MockExecutor::new("test".to_string(), "".to_string()));
    let tool_executor = Arc::new(MockToolExecutor::new("test".to_string()));
    let router = ToolRouter::new(config, vec![], executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("directory sandbox"));
    assert!(instructions.contains("/tmp/sandbox"));
}

#[test]
fn test_get_info_default_sandbox() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directory: None,
    };
    let executor = Arc::new(MockExecutor::new("test".to_string(), "".to_string()));
    let tool_executor = Arc::new(MockToolExecutor::new("test".to_string()));
    let router = ToolRouter::new(config, vec![], executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("current working directory"));
}

#[test]
fn test_get_info_basic_fields() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directory: None,
    };
    let executor = Arc::new(MockExecutor::new("test".to_string(), "".to_string()));
    let tool_executor = Arc::new(MockToolExecutor::new("test".to_string()));
    let router = ToolRouter::new(config, vec![], executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    assert_eq!(info.server_info.name, "nu-mcp");
    assert!(info.server_info.title.is_some());
    assert_eq!(info.server_info.title.unwrap(), "Nu MCP Server".to_string());
}

// Router tests
fn create_test_router() -> ToolRouter {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directory: Some(PathBuf::from("/tmp")),
    };
    let executor = Arc::new(MockExecutor::new("test output".to_string(), "".to_string()));
    let tool_executor = Arc::new(MockToolExecutor::new("tool output".to_string()));
    ToolRouter::new(config, vec![], executor, tool_executor)
}

#[tokio::test]
async fn test_router_run_nushell() {
    let router = create_test_router();

    let mut args = serde_json::Map::new();
    args.insert(
        "command".to_string(),
        serde_json::Value::String("echo hello".to_string()),
    );

    let request = CallToolRequestParam {
        name: "run_nushell".into(),
        arguments: Some(args),
    };

    let result = router.route_call(request).await;
    assert!(result.is_ok());

    let call_result = result.unwrap();
    assert!(!call_result.content.is_empty());
}

#[tokio::test]
async fn test_router_unknown_tool() {
    let router = create_test_router();

    let request = CallToolRequestParam {
        name: "unknown_tool".into(),
        arguments: None,
    };

    let result = router.route_call(request).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_router_extension_tool() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directory: Some(PathBuf::from("/tmp")),
    };

    let extension = crate::tools::ExtensionTool {
        module_path: PathBuf::from("/test/path"),
        tool_definition: Tool {
            name: "test_tool".into(),
            description: None,
            input_schema: Arc::new(serde_json::Map::new()),
            annotations: None,
            title: None,
            output_schema: None,
            icons: None,
        },
    };

    let executor = Arc::new(MockExecutor::new("test output".to_string(), "".to_string()));
    let tool_executor = Arc::new(MockToolExecutor::new("extension output".to_string()));
    let router = ToolRouter::new(config, vec![extension], executor, tool_executor);

    let request = CallToolRequestParam {
        name: "test_tool".into(),
        arguments: None,
    };

    let result = router.route_call(request).await;
    assert!(result.is_ok());

    let call_result = result.unwrap();
    assert!(!call_result.content.is_empty());
}

// Formatter tests
#[test]
fn test_success_formatter() {
    let result = ResultFormatter::success("test output".to_string());
    assert_eq!(result.content.len(), 1);
    // Just verify the result has content, specific pattern matching varies by rmcp version
    assert!(!result.content.is_empty());
}

#[test]
fn test_success_with_stderr_formatter() {
    let result = ResultFormatter::success_with_stderr("output".to_string(), "warning".to_string());
    assert_eq!(result.content.len(), 2);
    // Just verify the result has both stdout and stderr content
    assert!(!result.content.is_empty());
}

#[test]
fn test_success_with_empty_stderr() {
    let result = ResultFormatter::success_with_stderr("output".to_string(), "".to_string());
    assert_eq!(result.content.len(), 1);
    // Just verify the result has only stdout content
    assert!(!result.content.is_empty());
}

#[test]
fn test_error_formatter() {
    let result = ResultFormatter::error("test error".to_string());
    assert!(result.is_err());

    if let Err(error_data) = result {
        assert!(error_data.message.contains("test error"));
    }
}

#[test]
fn test_invalid_request_formatter() {
    let result = ResultFormatter::invalid_request("invalid request".to_string());
    assert!(result.is_err());

    if let Err(error_data) = result {
        assert!(error_data.message.contains("invalid request"));
    }
}
