use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(author, version, about)]
pub struct Cli {
    /// Directory containing nushell tool modules (directories with mod.nu files)
    #[arg(long, short = 't')]
    pub tools_dir: Option<PathBuf>,

    /// Enable the default `run` tool when using tools-dir
    #[arg(long, short = 'e', default_value_t = false)]
    pub enable_nu: bool,

    /// Add additional paths where commands can access files (can be specified multiple times)
    /// The current working directory is always accessible. This adds additional paths.
    #[arg(long = "add-path", short = 'p')]
    pub add_paths: Vec<PathBuf>,

    /// Block all network access for sandboxed commands
    #[arg(long, short = 'n', default_value_t = false)]
    pub block_network: bool,

    /// Unblock a sensitive path (can be specified multiple times)
    #[arg(long = "bypass-protection", short = 'b')]
    pub bypass_protection: Vec<PathBuf>,

    /// Add a read-only sandbox directory (can be specified multiple times)
    #[arg(long = "add-read-path", short = 'r')]
    pub read_only_paths: Vec<PathBuf>,

    /// Allow an external binary in the sandbox (can be specified multiple times)
    #[arg(long = "allow-binary", short = 'a')]
    pub allow_binaries: Vec<String>,
}

#[cfg(test)]
#[path = "../../test/cli/mod_test.rs"]
mod mod_test;
