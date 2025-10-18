use super::{NushellTool, ToolRouter};
use crate::config::Config;
use crate::execution::MockExecutor;
use crate::tools::MockToolExecutor;
use rmcp::handler::server::ServerHandler;
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
