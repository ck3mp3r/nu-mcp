use std::path::PathBuf;

#[derive(Debug, Clone, Default)]
pub struct Config {
    pub tools_dir: Option<PathBuf>,
    pub enable_run_nushell: bool,
    pub sandbox_directories: Vec<PathBuf>,
}

#[cfg(test)]
mod mod_test;
