use crate::filter::{Config, is_command_allowed};

fn default_config() -> Config {
    Config {
        denied_commands: vec!["rm".into(), "shutdown".into()],
        allowed_commands: vec!["ls".into()],
        allow_sudo: false,
        tools_dir: None,
        enable_run_nushell: false,
        disable_run_nushell_path_traversal_check: false,
        disable_run_nushell_system_dir_check: false,
    }
}

#[test]
fn test_allowed_command() {
    let config = default_config();
    assert!(is_command_allowed(&config, "ls -l").is_ok());
}

#[test]
fn test_denied_command() {
    let config = default_config();
    assert!(is_command_allowed(&config, "rm -rf /").is_err());
}

#[test]
fn test_allowed_overrides_denied() {
    let mut config = default_config();
    config.allowed_commands.push("rm".into());
    assert!(is_command_allowed(&config, "rm -rf /").is_ok());
}

#[test]
fn test_sudo_denied() {
    let config = default_config();
    assert!(is_command_allowed(&config, "sudo ls").is_err());
}

#[test]
fn test_sudo_allowed() {
    let mut config = default_config();
    config.allow_sudo = true;
    assert!(is_command_allowed(&config, "sudo ls").is_ok());
}