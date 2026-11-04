use super::{NushellTool, ToolRouter};
use crate::config::Config;
use crate::execution::NushellExecutor;
use crate::tools::MockToolExecutor;
use rmcp::handler::server::ServerHandler;
use std::path::PathBuf;

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

#[test]
fn test_get_info_includes_sandbox_info() -> Result<()> {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![PathBuf::from("/tmp/sandbox")],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info
        .instructions
        .ok_or("instructions message should be set")?;
    assert!(instructions.contains("Accessible directories"));
    assert!(instructions.contains("/tmp/sandbox"));
    Ok(())
}

#[test]
fn test_get_info_default_sandbox() -> Result<()> {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info
        .instructions
        .ok_or("instructions message should be set")?;
    assert!(instructions.contains("current working directory"));
    Ok(())
}

#[test]
fn test_get_info_basic_fields() -> Result<()> {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    assert_eq!(info.server_info.name, "nu-mcp");
    assert!(info.server_info.title.is_some());
    assert_eq!(
        info.server_info.title.ok_or("server title should be set")?,
        "Nu MCP Server".to_string()
    );
    Ok(())
}

#[test]
fn test_get_info_marks_current_directory() -> Result<()> {
    // When current directory is in the sandbox list, it should be labeled
    let cwd = std::env::current_dir()?;
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![cwd.clone(), PathBuf::from("/tmp")],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("test".to_string());
    let router = ToolRouter::new(config, vec![], stateless_executor, tool_executor);
    let tool = NushellTool { router };
    let info = tool.get_info();
    let instructions = info
        .instructions
        .ok_or("instructions message should be set")?;
    assert!(
        instructions.contains("(current directory)"),
        "Should label current directory: {}",
        instructions
    );
    Ok(())
}
