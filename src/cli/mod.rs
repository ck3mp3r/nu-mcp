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

    /// Add additional paths where commands can access files (can be specified multiple times)
    /// The current working directory is always accessible. This adds additional paths.
    #[arg(long = "add-path")]
    pub add_paths: Vec<PathBuf>,
}

#[cfg(test)]
mod mod_test;
