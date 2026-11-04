use super::Cli;
use clap::Parser;
use std::path::PathBuf;

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

#[test]
fn test_default_args() -> Result<()> {
    let args = Cli::try_parse_from(["nu-mcp"])?;

    assert!(args.tools_dir.is_none());
    assert!(!args.enable_nu);
    assert!(args.add_paths.is_empty());
    assert!(!args.block_network);
    assert!(args.bypass_protection.is_empty());
    assert!(args.read_only_paths.is_empty());
    assert!(args.allow_binaries.is_empty());
    assert!(args.env_credentials.is_empty());
    assert!(args.keyring_service.is_none());
    assert!(!args.disable_sandbox);
    Ok(())
}

#[test]
fn test_tools_dir_flag() -> Result<()> {
    let args = Cli::try_parse_from(["nu-mcp", "--tools-dir", "/path/to/tools"])?;

    assert_eq!(args.tools_dir, Some(PathBuf::from("/path/to/tools")));
    Ok(())
}

#[test]
fn test_enable_nu_flag() -> Result<()> {
    let args = Cli::try_parse_from(["nu-mcp", "--enable-nu"])?;

    assert!(args.enable_nu);
    Ok(())
}

#[test]
fn test_add_path_flag_repeatable() -> Result<()> {
    let args = Cli::try_parse_from(["nu-mcp", "--add-path", "/tmp", "--add-path", "/var/log"])?;

    assert_eq!(
        args.add_paths,
        vec![PathBuf::from("/tmp"), PathBuf::from("/var/log")]
    );
    Ok(())
}

#[test]
fn test_block_network_flag() -> Result<()> {
    let args = Cli::try_parse_from(["nu-mcp", "--block-network"])?;

    assert!(args.block_network);
    Ok(())
}

#[test]
fn test_bypass_protection_flag_repeatable() -> Result<()> {
    let args = Cli::try_parse_from([
        "nu-mcp",
        "--bypass-protection",
        "/home/user/.kube",
        "--bypass-protection",
        "/home/user/.aws",
    ])?;

    assert_eq!(
        args.bypass_protection,
        vec![
            PathBuf::from("/home/user/.kube"),
            PathBuf::from("/home/user/.aws")
        ]
    );
    Ok(())
}

#[test]
fn test_add_read_path_flag_repeatable() -> Result<()> {
    let args = Cli::try_parse_from([
        "nu-mcp",
        "--add-read-path",
        "/etc/ssl",
        "--add-read-path",
        "/usr/share",
    ])?;

    assert_eq!(
        args.read_only_paths,
        vec![PathBuf::from("/etc/ssl"), PathBuf::from("/usr/share")]
    );
    Ok(())
}

#[test]
fn test_allow_binary_flag_repeatable() -> Result<()> {
    let args = Cli::try_parse_from(["nu-mcp", "--allow-binary", "curl", "--allow-binary", "git"])?;

    assert_eq!(
        args.allow_binaries,
        vec!["curl".to_string(), "git".to_string()]
    );
    Ok(())
}

#[test]
fn test_env_credential_flag_repeatable() -> Result<()> {
    // -- Setup & Fixtures
    let args = vec![
        "nu-mcp",
        "--env-credential",
        "file:///run/secrets/api-token=API_TOKEN",
        "--env-credential",
        "keyring://nu-mcp/git=GIT_TOKEN",
    ];

    // -- Exec
    let cli = Cli::try_parse_from(args)?;

    // -- Check
    assert_eq!(
        cli.env_credentials,
        vec![
            "file:///run/secrets/api-token=API_TOKEN".to_string(),
            "keyring://nu-mcp/git=GIT_TOKEN".to_string(),
        ]
    );
    Ok(())
}

#[test]
fn test_keyring_service_flag() -> Result<()> {
    // -- Setup & Fixtures
    let args = vec!["nu-mcp", "--keyring-service", "my-service"];

    // -- Exec
    let cli = Cli::try_parse_from(args)?;

    // -- Check
    assert_eq!(cli.keyring_service.as_deref(), Some("my-service"));
    Ok(())
}

#[test]
fn test_disable_sandbox_flag() -> Result<()> {
    // -- Setup & Fixtures
    let args = vec!["nu-mcp", "--disable-sandbox"];

    // -- Exec
    let cli = Cli::try_parse_from(args)?;

    // -- Check
    assert!(
        cli.disable_sandbox,
        "--disable-sandbox should parse as true"
    );
    Ok(())
}

#[test]
fn test_disable_sandbox_flag_has_no_short_form() -> Result<()> {
    // -- Setup & Fixtures
    let args = vec!["nu-mcp", "-d"];

    // -- Exec
    let parsed = Cli::try_parse_from(args);

    // -- Check
    assert!(
        parsed.is_err(),
        "--disable-sandbox must not carry a short form"
    );
    Ok(())
}

#[test]
fn test_all_flags_combined() -> Result<()> {
    let args = Cli::try_parse_from([
        "nu-mcp",
        "--tools-dir",
        "/opt/tools",
        "--enable-nu",
        "--add-path",
        "/tmp",
        "--block-network",
        "--bypass-protection",
        "/home/user/.kube",
        "--add-read-path",
        "/etc/ssl",
        "--allow-binary",
        "curl",
        "--env-credential",
        "file:///run/secrets/api-token=API_TOKEN",
        "--keyring-service",
        "my-service",
        "--disable-sandbox",
    ])?;

    assert_eq!(args.tools_dir, Some(PathBuf::from("/opt/tools")));
    assert!(args.enable_nu);
    assert_eq!(args.add_paths, vec![PathBuf::from("/tmp")]);
    assert!(args.block_network);
    assert_eq!(
        args.bypass_protection,
        vec![PathBuf::from("/home/user/.kube")]
    );
    assert_eq!(args.read_only_paths, vec![PathBuf::from("/etc/ssl")]);
    assert_eq!(args.allow_binaries, vec!["curl".to_string()]);
    assert_eq!(
        args.env_credentials,
        vec!["file:///run/secrets/api-token=API_TOKEN".to_string()]
    );
    assert_eq!(args.keyring_service.as_deref(), Some("my-service"));
    assert!(args.disable_sandbox);
    Ok(())
}

#[test]
fn test_invalid_flag_fails() {
    let result = Cli::try_parse_from(["nu-mcp", "--invalid-flag"]);

    assert!(result.is_err());
}
