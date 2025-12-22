use async_trait::async_trait;
use std::path::Path;

#[async_trait]
pub trait CommandExecutor: Send + Sync {
    async fn execute(
        &self,
        command: &str,
        working_dir: &Path,
        timeout_secs: Option<u64>,
    ) -> Result<(String, String), String>;
}

pub mod nushell;
pub use nushell::NushellExecutor;

#[cfg(test)]
pub mod mock;
#[cfg(test)]
pub use mock::MockExecutor;

#[cfg(test)]
mod mock_test;
#[cfg(test)]
mod nushell_test;
