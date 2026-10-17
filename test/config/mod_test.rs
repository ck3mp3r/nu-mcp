use super::Config;
use std::path::PathBuf;

// Test simplified config creation

#[test]
fn test_config_creation_default() {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
    };

    assert!(config.tools_dir.is_none());
    assert!(!config.enable_nu);
    assert!(config.sandbox_directories.is_empty());
    assert!(!config.block_network);
    assert!(config.bypass_protection.is_empty());
    assert!(config.read_only_paths.is_empty());
    assert!(config.allow_binaries.is_empty());
}

#[test]
fn test_config_creation_tools_dir() {
    let tools_path = PathBuf::from("/test/tools");

    let config = Config {
        tools_dir: Some(tools_path.clone()),
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
    };

    assert_eq!(config.tools_dir, Some(tools_path));
}

#[test]
fn test_config_creation_enable_run() {
    let config = Config {
        tools_dir: None,
        enable_nu: true,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
    };

    assert!(config.enable_nu);
}

#[test]
fn test_config_creation_sandbox_directories() {
    let sandbox_path = PathBuf::from("/tmp/sandbox");

    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![sandbox_path.clone()],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
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
        enable_nu: true,
        sandbox_directories: vec![sandbox1.clone(), sandbox2.clone()],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
    };

    assert_eq!(config.tools_dir, Some(tools_path));
    assert!(config.enable_nu);
    assert_eq!(config.sandbox_directories, vec![sandbox1, sandbox2]);
}

#[test]
fn test_config_creation_sandbox_options() {
    let bypass = PathBuf::from("/home/user/.kube");
    let read_only = PathBuf::from("/etc/ssl");

    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: true,
        bypass_protection: vec![bypass.clone()],
        read_only_paths: vec![read_only.clone()],
        allow_binaries: vec![],
    };

    assert!(config.block_network);
    assert_eq!(config.bypass_protection, vec![bypass]);
    assert_eq!(config.read_only_paths, vec![read_only]);
}

#[test]
fn test_config_creation_allow_binaries() {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec!["curl".to_string(), "git".to_string()],
    };

    assert_eq!(
        config.allow_binaries,
        vec!["curl".to_string(), "git".to_string()]
    );
}
