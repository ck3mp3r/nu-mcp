use anyhow::Result;
use clap::Parser;
use nu_mcp::{cli::Cli, config::Config, mcp::run_server};
use std::env;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing subscriber for debug logging
    // Control log level with RUST_LOG env var (e.g., RUST_LOG=nu_mcp=debug)
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("nu_mcp=info")),
        )
        .init();

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
