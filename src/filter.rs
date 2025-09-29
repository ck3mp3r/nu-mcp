#[derive(Debug, Clone, Default)]
pub struct Config {
    pub denied_commands: Vec<String>,
    pub allowed_commands: Vec<String>,
    pub allow_sudo: bool,
    pub tools_dir: Option<std::path::PathBuf>,
    pub enable_run_nushell: bool,
    pub disable_run_nushell_path_traversal_check: bool,
    pub disable_run_nushell_system_dir_check: bool,
}

pub fn is_command_allowed(config: &Config, command: &str) -> Result<(), String> {
    let first_word = command.split_whitespace().next().unwrap_or("");
    if !config.allowed_commands.iter().any(|ac| first_word == ac)
        && config.denied_commands.iter().any(|dc| first_word == dc)
    {
        return Err(format!(
            "Command '{first_word}' is denied by server configuration"
        ));
    }
    if !config.allow_sudo && first_word == "sudo" {
        return Err("Use of 'sudo' is not permitted by server configuration".to_string());
    }
    Ok(())
}
