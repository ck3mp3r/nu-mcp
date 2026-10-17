use super::{NushellTool, ToolRouter};
use crate::config::Config;
use crate::execution::NushellExecutor;
use crate::tools::MockToolExecutor;
use rmcp::handler::server::ServerHandler;
use std::path::PathBuf;

#[test]
fn test_get_info_includes_sandbox_info() {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![PathBuf::from("/tmp/sandbox")],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("Accessible directories"));
    assert!(instructions.contains("/tmp/sandbox"));
}

#[test]
fn test_get_info_default_sandbox() {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("current working directory"));
}

#[test]
fn test_get_info_basic_fields() {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    assert_eq!(info.server_info.name, "nu-mcp");
    assert!(info.server_info.title.is_some());
    assert_eq!(info.server_info.title.unwrap(), "Nu MCP Server".to_string());
}

#[test]
fn test_get_info_marks_current_directory() {
    // When current directory is in the sandbox list, it should be labeled
    let cwd = std::env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![cwd.clone(), PathBuf::from("/tmp")],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(
        instructions.contains("(current directory)"),
        "Should label current directory: {}",
        instructions
    );
}
