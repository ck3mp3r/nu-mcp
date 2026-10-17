use std::path::PathBuf;

#[derive(Debug, Clone, Default)]
pub struct Config {
    pub tools_dir: Option<PathBuf>,
    pub enable_nu: bool,
    pub sandbox_directories: Vec<PathBuf>,
    pub block_network: bool,
    pub bypass_protection: Vec<PathBuf>,
    pub read_only_paths: Vec<PathBuf>,
}

#[cfg(test)]
#[path = "../../test/config/mod_test.rs"]
mod mod_test;
