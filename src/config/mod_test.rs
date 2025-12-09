use super::Config;
use std::path::PathBuf;

// Test simplified config creation

#[test]
fn test_config_creation_default() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directories: vec![],
    };

    assert!(config.tools_dir.is_none());
    assert!(!config.enable_run_nushell);
    assert!(config.sandbox_directories.is_empty());
}

#[test]
fn test_config_creation_tools_dir() {
    let tools_path = PathBuf::from("/test/tools");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: false,
        sandbox_directories: vec![],
    };

    assert_eq!(config.tools_dir, Some(tools_path));
}

#[test]
fn test_config_creation_enable_run_nushell() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directories: vec![],
    };

    assert!(config.enable_run_nushell);
}

#[test]
fn test_config_creation_sandbox_directories() {
    let sandbox_path = PathBuf::from("/tmp/sandbox");

    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directories: vec![sandbox_path.clone()],
    };

    assert_eq!(config.sandbox_directories, vec![sandbox_path]);
}

#[test]
fn test_config_creation_full_configuration() {
    let tools_path = PathBuf::from("/custom/tools");
    let sandbox1 = PathBuf::from("/custom/sandbox1");
    let sandbox2 = PathBuf::from("/custom/sandbox2");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: true,
        sandbox_directories: vec![sandbox1.clone(), sandbox2.clone()],
    };

    assert_eq!(config.tools_dir, Some(tools_path));
    assert!(config.enable_run_nushell);
    assert_eq!(config.sandbox_directories, vec![sandbox1, sandbox2]);
}
