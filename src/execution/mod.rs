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

    /// Reset the executor to a clean state (e.g., fresh shell).
    /// Default implementation is a no-op for stateless executors.
    fn reset(&self) -> Result<(), String> {
        Ok(())
    }
}

pub mod nushell;
pub use nushell::NushellExecutor;

pub mod osc133;
pub mod persistent;

#[cfg(test)]
pub mod mock;
#[cfg(test)]
pub use mock::MockExecutor;

#[cfg(test)]
mod mock_test;
#[cfg(test)]
mod nushell_test;
#[cfg(test)]
mod persistent_test;
