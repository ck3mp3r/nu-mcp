use anyhow::Result;
use clap::Parser;
use nu_mcp::{cli::Cli, config::Config, mcp::run_server};
use std::env;

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Default to current directory ONLY if no sandboxes specified
    // If sandboxes are explicitly provided, use only those
    let sandbox_directories = if cli.sandbox_dirs.is_empty() {
        vec![env::current_dir()?]
    } else {
        cli.sandbox_dirs
    };

    let config = Config {
        tools_dir: cli.tools_dir,
        enable_run_nushell: cli.enable_run_nushell,
        sandbox_directories,
    };

    run_server(config).await
}
