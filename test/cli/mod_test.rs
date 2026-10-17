use super::Cli;
use clap::Parser;
use std::path::PathBuf;

#[test]
fn test_default_args() {
    let args = Cli::try_parse_from(["nu-mcp"]).expect("Failed to parse default args");

    assert!(args.tools_dir.is_none());
    assert!(!args.enable_nu);
    assert!(args.add_paths.is_empty());
    assert!(!args.block_network);
    assert!(args.bypass_protection.is_empty());
    assert!(args.read_only_paths.is_empty());
}

#[test]
fn test_tools_dir_flag() {
    let args = Cli::try_parse_from(["nu-mcp", "--tools-dir", "/path/to/tools"])
        .expect("Failed to parse tools-dir flag");

    assert_eq!(args.tools_dir, Some(PathBuf::from("/path/to/tools")));
}

#[test]
fn test_enable_nu_flag() {
    let args = Cli::try_parse_from(["nu-mcp", "--enable-nu"]).expect("Failed to parse --enable-nu");

    assert!(args.enable_nu);
}

#[test]
fn test_add_path_flag_repeatable() {
    let args = Cli::try_parse_from(["nu-mcp", "--add-path", "/tmp", "--add-path", "/var/log"])
        .expect("Failed to parse --add-path");

    assert_eq!(
        args.add_paths,
        vec![PathBuf::from("/tmp"), PathBuf::from("/var/log")]
    );
}

#[test]
fn test_block_network_flag() {
    let args = Cli::try_parse_from(["nu-mcp", "--block-network"])
        .expect("Failed to parse --block-network");

    assert!(args.block_network);
}

#[test]
fn test_bypass_protection_flag_repeatable() {
    let args = Cli::try_parse_from([
        "nu-mcp",
        "--bypass-protection",
        "/home/user/.kube",
        "--bypass-protection",
        "/home/user/.aws",
    ])
    .expect("Failed to parse --bypass-protection");

    assert_eq!(
        args.bypass_protection,
        vec![
            PathBuf::from("/home/user/.kube"),
            PathBuf::from("/home/user/.aws")
        ]
    );
}

#[test]
fn test_add_read_path_flag_repeatable() {
    let args = Cli::try_parse_from([
        "nu-mcp",
        "--add-read-path",
        "/etc/ssl",
        "--add-read-path",
        "/usr/share",
    ])
    .expect("Failed to parse --add-read-path");

    assert_eq!(
        args.read_only_paths,
        vec![PathBuf::from("/etc/ssl"), PathBuf::from("/usr/share")]
    );
}

#[test]
fn test_all_flags_combined() {
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
    ])
    .expect("Failed to parse combined flags");

    assert_eq!(args.tools_dir, Some(PathBuf::from("/opt/tools")));
    assert!(args.enable_nu);
    assert_eq!(args.add_paths, vec![PathBuf::from("/tmp")]);
    assert!(args.block_network);
    assert_eq!(
        args.bypass_protection,
        vec![PathBuf::from("/home/user/.kube")]
    );
    assert_eq!(args.read_only_paths, vec![PathBuf::from("/etc/ssl")]);
}

#[test]
fn test_invalid_flag_fails() {
    let result = Cli::try_parse_from(["nu-mcp", "--invalid-flag"]);

    assert!(result.is_err());
}
