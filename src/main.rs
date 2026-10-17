use anyhow::{Context, Result};
use clap::Parser;
use nu_mcp::{cli::Cli, config::Config, mcp::run_server, security::build_capability_set};
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
        enable_nu: cli.enable_nu,
        sandbox_directories,
        block_network: cli.block_network,
        bypass_protection: cli.bypass_protection,
        read_only_paths: cli.read_only_paths,
    };

    // Apply the sandbox to this process before the server starts. Child `nu`
    // processes inherit it. Application is irreversible and fail-closed: if the
    // sandbox cannot be applied, the server must not run.
    let caps = build_capability_set(&config).context("failed to build sandbox capability set")?;
    nono::Sandbox::apply_auto(&caps).context("failed to apply sandbox")?;

    run_server(config).await
}
