use clap::Parser;
use std::path::PathBuf;

// Import the Args struct from main.rs
// Note: This test assumes the Args struct is made public or we create a test-specific version
#[derive(Parser, Debug, Clone)]
#[command(name = "nu-mcp")]
#[command(about = "Model Context Protocol (MCP) Server for Nushell")]
struct Args {
    #[arg(long, value_delimiter = ',')]
    denied_cmds: Vec<String>,

    #[arg(long, value_delimiter = ',')]
    allowed_cmds: Vec<String>,

    #[arg(long)]
    allow_sudo: bool,

    #[arg(long)]
    tools_dir: Option<PathBuf>,

    #[arg(long, default_value_t = false)]
    enable_run_nushell: bool,

    #[arg(short = 'P', long)]
    disable_run_nushell_path_traversal_check: bool,

    #[arg(short = 'S', long)]
    disable_run_nushell_system_dir_check: bool,
}

#[test]
fn test_default_args() {
    let args = Args::try_parse_from(&["nu-mcp"]).expect("Failed to parse default args");

    assert!(args.denied_cmds.is_empty());
    assert!(args.allowed_cmds.is_empty());
    assert!(!args.allow_sudo);
    assert!(args.tools_dir.is_none());
    assert!(!args.enable_run_nushell);
    assert!(!args.disable_run_nushell_path_traversal_check);
    assert!(!args.disable_run_nushell_system_dir_check);
}

#[test]
fn test_denied_commands_parsing() {
    let args = Args::try_parse_from(&["nu-mcp", "--denied-cmds", "rm,shutdown,reboot"])
        .expect("Failed to parse denied commands");

    assert_eq!(args.denied_cmds, vec!["rm", "shutdown", "reboot"]);
}

#[test]
fn test_allowed_commands_parsing() {
    let args = Args::try_parse_from(&["nu-mcp", "--allowed-cmds", "ls,cat,echo"])
        .expect("Failed to parse allowed commands");

    assert_eq!(args.allowed_cmds, vec!["ls", "cat", "echo"]);
}

#[test]
fn test_allow_sudo_flag() {
    let args =
        Args::try_parse_from(&["nu-mcp", "--allow-sudo"]).expect("Failed to parse allow-sudo flag");

    assert!(args.allow_sudo);
}

#[test]
fn test_tools_dir_flag() {
    let args = Args::try_parse_from(&["nu-mcp", "--tools-dir", "/path/to/tools"])
        .expect("Failed to parse tools-dir flag");

    assert_eq!(args.tools_dir, Some(PathBuf::from("/path/to/tools")));
}

#[test]
fn test_enable_run_nushell_flag() {
    let args = Args::try_parse_from(&["nu-mcp", "--enable-run-nushell"])
        .expect("Failed to parse enable-run-nushell flag");

    assert!(args.enable_run_nushell);
}

#[test]
fn test_security_filter_short_flags() {
    let args = Args::try_parse_from(&["nu-mcp", "-P", "-S"])
        .expect("Failed to parse security filter short flags");

    assert!(args.disable_run_nushell_path_traversal_check);
    assert!(args.disable_run_nushell_system_dir_check);
}

#[test]
fn test_security_filter_long_flags() {
    let args = Args::try_parse_from(&[
        "nu-mcp",
        "--disable-run-nushell-path-traversal-check",
        "--disable-run-nushell-system-dir-check",
    ])
    .expect("Failed to parse security filter long flags");

    assert!(args.disable_run_nushell_path_traversal_check);
    assert!(args.disable_run_nushell_system_dir_check);
}

#[test]
fn test_all_flags_combined() {
    let args = Args::try_parse_from(&[
        "nu-mcp",
        "--denied-cmds",
        "rm,shutdown",
        "--allowed-cmds",
        "ls,cat",
        "--allow-sudo",
        "--tools-dir",
        "/opt/tools",
        "--enable-run-nushell",
        "-P",
        "-S",
    ])
    .expect("Failed to parse combined flags");

    assert_eq!(args.denied_cmds, vec!["rm", "shutdown"]);
    assert_eq!(args.allowed_cmds, vec!["ls", "cat"]);
    assert!(args.allow_sudo);
    assert_eq!(args.tools_dir, Some(PathBuf::from("/opt/tools")));
    assert!(args.enable_run_nushell);
    assert!(args.disable_run_nushell_path_traversal_check);
    assert!(args.disable_run_nushell_system_dir_check);
}

#[test]
fn test_extension_mode_typical_usage() {
    let args = Args::try_parse_from(&["nu-mcp", "--tools-dir", "/opt/mcp-tools/weather"])
        .expect("Failed to parse extension mode args");

    assert_eq!(
        args.tools_dir,
        Some(PathBuf::from("/opt/mcp-tools/weather"))
    );
    assert!(!args.enable_run_nushell); // Default disabled with tools_dir
}

#[test]
fn test_hybrid_mode_typical_usage() {
    let args = Args::try_parse_from(&[
        "nu-mcp",
        "--tools-dir",
        "/opt/mcp-tools/dev",
        "--enable-run-nushell",
        "--allowed-cmds",
        "git,cargo,npm",
        "-P", // Allow file access for development
    ])
    .expect("Failed to parse hybrid mode args");

    assert_eq!(args.tools_dir, Some(PathBuf::from("/opt/mcp-tools/dev")));
    assert!(args.enable_run_nushell);
    assert_eq!(args.allowed_cmds, vec!["git", "cargo", "npm"]);
    assert!(args.disable_run_nushell_path_traversal_check);
}

#[test]
fn test_invalid_flag_fails() {
    let result = Args::try_parse_from(&["nu-mcp", "--invalid-flag"]);

    assert!(result.is_err());
}