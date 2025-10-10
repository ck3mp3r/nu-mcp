use crate::filter::Config;
use std::path::PathBuf;

// Test simplified config creation

#[test]
fn test_config_creation_default() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        jail_directory: None,
    };

    assert!(config.tools_dir.is_none());
    assert!(!config.enable_run_nushell);
    assert!(config.jail_directory.is_none());
}

#[test]
fn test_config_creation_tools_dir() {
    let tools_path = PathBuf::from("/test/tools");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: false,
        jail_directory: None,
    };

    assert_eq!(config.tools_dir, Some(tools_path));
}

#[test]
fn test_config_creation_enable_run_nushell() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        jail_directory: None,
    };

    assert!(config.enable_run_nushell);
}

#[test]
fn test_config_creation_jail_directory() {
    let jail_path = PathBuf::from("/tmp/jail");

    let config = Config {
        tools_dir: None,
        enable_run_nushell: false,
        jail_directory: Some(jail_path.clone()),
    };

    assert_eq!(config.jail_directory, Some(jail_path));
}

#[test]
fn test_config_creation_full_configuration() {
    let tools_path = PathBuf::from("/custom/tools");
    let jail_path = PathBuf::from("/custom/jail");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_run_nushell: true,
        jail_directory: Some(jail_path.clone()),
    };

    assert_eq!(config.tools_dir, Some(tools_path));
    assert!(config.enable_run_nushell);
    assert_eq!(config.jail_directory, Some(jail_path));
}
