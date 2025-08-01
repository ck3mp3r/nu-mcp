mod filter;
mod handler;

use clap::Parser;
use filter::Config;
use handler::run_server;

#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Cli {
    /// Comma-separated list of denied commands
    #[arg(long, value_delimiter = ',')]
    denied_cmds: Option<Vec<String>>,

    /// Comma-separated list of allowed commands (takes precedence over denied)
    #[arg(long, value_delimiter = ',')]
    allowed_cmds: Option<Vec<String>>,

    /// Allow sudo (default: false)
    #[arg(long, default_value_t = false)]
    allow_sudo: bool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    let default_denied = vec![
        "rm".to_string(),
        "shutdown".to_string(),
        "reboot".to_string(),
        "poweroff".to_string(),
        "halt".to_string(),
        "mkfs".to_string(),
        "dd".to_string(),
        "chmod".to_string(),
        "chown".to_string(),
    ];

    let config = Config {
        denied_commands: cli.denied_cmds.unwrap_or(default_denied),
        allowed_commands: cli.allowed_cmds.unwrap_or_default(),
        allow_sudo: cli.allow_sudo,
    };

    run_server(config).await
}
