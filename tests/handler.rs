use nu_mcp::filter::Config;
use nu_mcp::handler::NushellTool;
use rmcp::handler::server::ServerHandler;
use std::path::PathBuf;

#[test]
fn test_get_info_includes_allowed_and_denied() {
    let config = Config {
        allowed_commands: vec!["ls".into(), "cat".into()],
        denied_commands: vec!["rm".into(), "shutdown".into()],
        allow_sudo: true,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    let tool = NushellTool {
        config,
        extensions: vec![],
    };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("ls"));
    assert!(instructions.contains("cat"));
    assert!(instructions.contains("rm"));
    assert!(instructions.contains("shutdown"));
    assert!(instructions.contains("Sudo allowed: yes"));
}

#[test]
fn test_get_info_empty_lists() {
    let config = Config {
        allowed_commands: vec![],
        denied_commands: vec![],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    let tool = NushellTool {
        config,
        extensions: vec![],
    };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("(none specified)"));
    assert!(instructions.contains("Sudo allowed: no"));
}

#[test]
fn test_nushell_tool_creation_with_extensions() {
    let config = Config {
        allowed_commands: vec![],
        denied_commands: vec![],
        allow_sudo: false,
        tools_dir: Some(PathBuf::from("/test/tools")),
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };

    let tool = NushellTool {
        config,
        extensions: vec![],
    };

    // Verify extension mode configuration
    assert!(tool.extensions.is_empty());
    assert!(tool.config.tools_dir.is_some());
    assert!(!tool.config.enable_run_nushell);
}

#[test]
fn test_nushell_tool_creation_hybrid_mode() {
    let config = Config {
        allowed_commands: vec!["ls".to_string()],
        denied_commands: vec!["rm".to_string()],
        allow_sudo: false,
        tools_dir: Some(PathBuf::from("/test/tools")),
        enable_run_nushell: true,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };

    let tool = NushellTool {
        config,
        extensions: vec![],
    };

    // Verify hybrid mode configuration
    assert!(tool.extensions.is_empty());
    assert!(tool.config.tools_dir.is_some());
    assert!(tool.config.enable_run_nushell);
    assert_eq!(tool.config.allowed_commands, vec!["ls"]);
    assert_eq!(tool.config.denied_commands, vec!["rm"]);
}

#[test]
fn test_nushell_tool_creation_core_mode() {
    let config = Config {
        allowed_commands: vec!["ls".to_string(), "cat".to_string()],
        denied_commands: vec!["rm".to_string(), "shutdown".to_string()],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };

    let tool = NushellTool {
        config,
        extensions: vec![],
    };

    // Verify core mode configuration
    assert!(tool.extensions.is_empty());
    assert!(tool.config.tools_dir.is_none());
    assert!(!tool.config.enable_run_nushell);
    assert_eq!(tool.config.allowed_commands, vec!["ls", "cat"]);
    assert_eq!(tool.config.denied_commands, vec!["rm", "shutdown"]);
}
