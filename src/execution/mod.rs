use std::path::Path;

const DEFAULT_TIMEOUT_SECS: u64 = 300;

/// Get default timeout from environment variable or built-in default
pub(crate) fn get_default_timeout() -> u64 {
    std::env::var("MCP_NU_MCP_TIMEOUT")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(DEFAULT_TIMEOUT_SECS)
}

pub trait CommandExecutor: Send + Sync {
    fn execute(
        &self,
        command: &str,
        working_dir: &Path,
        timeout_secs: Option<u64>,
    ) -> impl std::future::Future<Output = Result<(String, String), String>> + Send;

    /// Reset the executor to a clean state (e.g., fresh shell).
    /// Default implementation is a no-op for stateless executors.
    fn reset(&self) -> impl std::future::Future<Output = Result<(), String>> + Send {
        async { Ok(()) }
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
