use std::path::PathBuf;

#[derive(Debug, Clone, Default)]
pub struct Config {
    pub tools_dir: Option<PathBuf>,
    pub enable_run_nushell: bool,
    pub sandbox_directory: Option<PathBuf>,
}

#[cfg(test)]
mod tests;
