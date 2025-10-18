use super::Config;
use std::path::PathBuf;

// Test simplified config creation

#[test]
fn test_config_creation_default() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directory: None,
    };

    assert!(config.tools_dir.is_none());
    assert!(!config.enable_run_nushell);
    assert!(config.sandbox_directory.is_none());
}

#[test]
fn test_config_creation_tools_dir() {
    let tools_path = PathBuf::from("/test/tools");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: false,
        sandbox_directory: None,
    };

    assert_eq!(config.tools_dir, Some(tools_path));
}

#[test]
fn test_config_creation_enable_run_nushell() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directory: None,
    };

    assert!(config.enable_run_nushell);
}

#[test]
fn test_config_creation_sandbox_directory() {
    let sandbox_path = PathBuf::from("/tmp/sandbox");

    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        sandbox_directory: Some(sandbox_path.clone()),
    };

    assert_eq!(config.sandbox_directory, Some(sandbox_path));
}

#[test]
fn test_config_creation_full_configuration() {
    let tools_path = PathBuf::from("/custom/tools");
    let sandbox_path = PathBuf::from("/custom/jail");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: true,
        sandbox_directory: Some(sandbox_path.clone()),
    };

    assert_eq!(config.tools_dir, Some(tools_path));
    assert!(config.enable_run_nushell);
    assert_eq!(config.sandbox_directory, Some(sandbox_path));
}
