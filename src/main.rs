use anyhow::Result;
use clap::Parser;
use nu_mcp::{cli::Cli, config::Config, mcp::run_server};
use std::env;

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Always include current directory, plus any additional paths
    let mut sandbox_directories = vec![env::current_dir()?];
    sandbox_directories.extend(cli.add_paths);

    let config = Config {
        tools_dir: cli.tools_dir,
        enable_run_nushell: cli.enable_run_nushell,
        sandbox_directories,
    };

    run_server(config).await
}
