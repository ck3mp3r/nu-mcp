use clap::Parser;
use nu_mcp::{cli::Cli, config::Config, mcp::run_server};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    let config = Config {
        tools_dir: cli.tools_dir,
        enable_run_nushell: cli.enable_run_nushell,
        sandbox_directory: cli.sandbox_dir,
    };

    run_server(config).await
}
