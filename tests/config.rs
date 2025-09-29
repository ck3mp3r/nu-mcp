use nu_mcp::filter::Config;
use std::path::PathBuf;

// Test CLI argument parsing and config creation
// We can't easily test the actual main() function due to tokio::main and server startup,
// but we can test the config logic that main() uses

#[test]
fn test_config_creation_default_denied_commands() {
    // Simulate what main() does for denied commands
    let cli_denied_cmds: Option<Vec<String>> = None;
    
    let default_denied = vec![
        "rm".to_string(),
        "shutdown".to_string(),
        "reboot".to_string(),
        "poweroff".to_string(),
        "halt".to_string(),
        "mkfs".to_string(),
        "dd".to_string(),
        "chmod".to_string(),
        "chown".to_string(),
    ];
    
    let config = Config {
        denied_commands: cli_denied_cmds.unwrap_or(default_denied.clone()),
        allowed_commands: vec![],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    
    assert_eq!(config.denied_commands, default_denied);
    assert!(config.allowed_commands.is_empty());
    assert!(!config.allow_sudo);
    assert!(config.tools_dir.is_none());
    assert!(!config.enable_run_nushell);
    assert!(!config.disable_run_nushell_path_traversal_check);
    assert!(!config.disable_run_nushell_system_dir_check);
}

#[test]
fn test_config_creation_custom_denied_commands() {
    // Simulate CLI providing custom denied commands
    let cli_denied_cmds: Option<Vec<String>> = Some(vec!["custom_cmd".to_string()]);
    
    let default_denied = vec![
        "rm".to_string(),
        "shutdown".to_string(),
        "reboot".to_string(),
        "poweroff".to_string(),
        "halt".to_string(),
        "mkfs".to_string(),
        "dd".to_string(),
        "chmod".to_string(),
        "chown".to_string(),
    ];
    
    let config = Config {
        denied_commands: cli_denied_cmds.unwrap_or(default_denied),
        allowed_commands: vec![],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    
    assert_eq!(config.denied_commands, vec!["custom_cmd"]);
}

#[test]
fn test_config_creation_custom_allowed_commands() {
    // Simulate CLI providing allowed commands
    let cli_allowed_cmds: Option<Vec<String>> = Some(vec!["echo".to_string(), "ls".to_string()]);
    
    let config = Config {
        denied_commands: vec![], // Using empty for simplicity in test
        allowed_commands: cli_allowed_cmds.unwrap_or_default(),
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    
    assert_eq!(config.allowed_commands, vec!["echo", "ls"]);
}

#[test]
fn test_config_creation_allow_sudo_true() {
    let config = Config {
        denied_commands: vec![],
        allowed_commands: vec![],
        allow_sudo: true, // Simulate --allow-sudo flag
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    
    assert!(config.allow_sudo);
}

#[test]
fn test_config_creation_tools_dir() {
    let tools_path = PathBuf::from("/test/tools");
    
    let config = Config {
        denied_commands: vec![],
        allowed_commands: vec![],
        allow_sudo: false,
        tools_dir: Some(tools_path.clone()), // Simulate --tools-dir flag
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    
    assert_eq!(config.tools_dir, Some(tools_path));
}

#[test]
fn test_config_creation_enable_run_nushell() {
    let config = Config {
        denied_commands: vec![],
        allowed_commands: vec![],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: true, // Simulate --enable-run-nushell flag
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    };
    
    assert!(config.enable_run_nushell);
}

#[test]
fn test_config_creation_disable_path_traversal_check() {
    let config = Config {
        denied_commands: vec![],
        allowed_commands: vec![],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: true, // Simulate -P flag
        disable_run_nushell_system_dir_check: false,
    };
    
    assert!(config.disable_run_nushell_path_traversal_check);
}

#[test]
fn test_config_creation_disable_system_dir_check() {
    let config = Config {
        denied_commands: vec![],
        allowed_commands: vec![],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: true, // Simulate -S flag
    };
    
    assert!(config.disable_run_nushell_system_dir_check);
}

#[test]
fn test_config_creation_full_configuration() {
    // Test a complex configuration simulating multiple CLI flags
    let cli_denied_cmds = Some(vec!["rm".to_string(), "custom".to_string()]);
    let cli_allowed_cmds = Some(vec!["echo".to_string(), "ls".to_string(), "cat".to_string()]);
    let tools_path = PathBuf::from("/custom/tools");
    
    let config = Config {
        denied_commands: cli_denied_cmds.unwrap_or_default(),
        allowed_commands: cli_allowed_cmds.unwrap_or_default(),
        allow_sudo: true,
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: true,
        disable_run_nushell_path_traversal_check: true,
        disable_run_nushell_system_dir_check: true,
    };
    
    assert_eq!(config.denied_commands, vec!["rm", "custom"]);
    assert_eq!(config.allowed_commands, vec!["echo", "ls", "cat"]);
    assert!(config.allow_sudo);
    assert_eq!(config.tools_dir, Some(tools_path));
    assert!(config.enable_run_nushell);
    assert!(config.disable_run_nushell_path_traversal_check);
    assert!(config.disable_run_nushell_system_dir_check);
}

#[test]
fn test_default_denied_commands_completeness() {
    // Test that we have all expected default denied commands
    let default_denied = vec![
        "rm".to_string(),
        "shutdown".to_string(),
        "reboot".to_string(),
        "poweroff".to_string(),
        "halt".to_string(),
        "mkfs".to_string(),
        "dd".to_string(),
        "chmod".to_string(),
        "chown".to_string(),
    ];
    
    // Verify dangerous commands are included
    assert!(default_denied.contains(&"rm".to_string()));
    assert!(default_denied.contains(&"shutdown".to_string()));
    assert!(default_denied.contains(&"reboot".to_string()));
    assert!(default_denied.contains(&"poweroff".to_string()));
    assert!(default_denied.contains(&"halt".to_string()));
    assert!(default_denied.contains(&"mkfs".to_string()));
    assert!(default_denied.contains(&"dd".to_string()));
    assert!(default_denied.contains(&"chmod".to_string()));
    assert!(default_denied.contains(&"chown".to_string()));
    
    // Verify count
    assert_eq!(default_denied.len(), 9);
}

#[test]
fn test_unwrap_or_default_behavior() {
    // Test the unwrap_or_default behavior used in main()
    let empty_vec: Option<Vec<String>> = None;
    let result = empty_vec.unwrap_or_default();
    assert!(result.is_empty());
    
    let some_vec = Some(vec!["test".to_string()]);
    let result = some_vec.unwrap_or_default();
    assert_eq!(result, vec!["test"]);
}