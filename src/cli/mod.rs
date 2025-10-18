use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(author, version, about)]
pub struct Cli {
    /// Directory containing nushell tool modules (directories with mod.nu files)
    #[arg(long)]
    pub tools_dir: Option<PathBuf>,

    /// Enable the default `run_nushell` tool when using tools-dir
    #[arg(long, default_value_t = false)]
    pub enable_run_nushell: bool,

    /// Directory to sandbox nushell execution (default: current working directory)
    #[arg(long)]
    pub sandbox_dir: Option<PathBuf>,
}

#[cfg(test)]
mod tests;
