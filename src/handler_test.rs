use crate::filter::Config;
use crate::handler::NushellTool;
use rmcp::handler::server::ServerHandler;
use std::path::PathBuf;

#[test]
fn test_get_info_includes_sandbox_info() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directory: Some(PathBuf::from("/tmp/sandbox")),
    };
    let tool = NushellTool {
        config,
        extensions: vec![],
    };
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
    let tool = NushellTool {
        config,
        extensions: vec![],
    };
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
    let tool = NushellTool {
        config,
        extensions: vec![],
    };
    let info = tool.get_info();
    assert_eq!(info.server_info.name, "nu-mcp");
    assert!(info.server_info.title.is_some());
    assert_eq!(info.server_info.title.unwrap(), "Nu MCP Server".to_string());
}
