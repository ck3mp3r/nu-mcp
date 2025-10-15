mod filter;
mod handler;
mod tools;

use clap::Parser;
use filter::Config;
use handler::run_server;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Cli {
    /// Directory containing nushell tool modules (directories with mod.nu files)
    #[arg(long)]
    tools_dir: Option<PathBuf>,

    /// Enable the default run_nushell tool when using tools-dir
    #[arg(long, default_value_t = false)]
    enable_run_nushell: bool,

    /// Directory to sandbox nushell execution (default: current working directory)
    #[arg(long)]
    sandbox_dir: Option<PathBuf>,
}

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
