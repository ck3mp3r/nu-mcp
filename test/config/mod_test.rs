use super::Config;
use crate::auth::parse_env_credentials;
use std::path::PathBuf;

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
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
        env_credentials: vec![],
        keyring_service: None,
        disable_sandbox: false,
    };

    assert_eq!(
        config.allow_binaries,
        vec!["curl".to_string(), "git".to_string()]
    );
}

#[test]
fn test_config_creation_env_credentials_verbatim() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec![
        "file:///run/secrets/api-token=API_TOKEN".to_string(),
        "keyring://nu-mcp/git=GIT_TOKEN".to_string(),
    ];

    // -- Exec
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
        env_credentials: values.clone(),
        keyring_service: None,
        disable_sandbox: false,
    };

    // -- Check
    assert_eq!(config.env_credentials, values);
    let pairs = parse_env_credentials(&config.env_credentials)?;
    assert_eq!(
        pairs,
        vec![
            (
                "file:///run/secrets/api-token".to_string(),
                "API_TOKEN".to_string()
            ),
            ("keyring://nu-mcp/git".to_string(), "GIT_TOKEN".to_string()),
        ]
    );
    assert!(config.keyring_service.is_none());
    Ok(())
}

#[test]
fn test_config_creation_keyring_service_and_disable_sandbox() {
    let config = Config {
        tools_dir: None,
        enable_nu: false,
        sandbox_directories: vec![],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
        allow_binaries: vec![],
        env_credentials: vec![],
        keyring_service: Some("my-service".to_string()),
        disable_sandbox: true,
    };

    assert_eq!(config.keyring_service.as_deref(), Some("my-service"));
    assert!(config.disable_sandbox);
}
