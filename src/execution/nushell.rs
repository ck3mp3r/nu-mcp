use super::CommandExecutor;
use async_trait::async_trait;
use std::{env, path::Path, process::Stdio, time::Duration};
use tokio::process::Command;
use tokio::time::timeout;

const DEFAULT_TIMEOUT_SECS: u64 = 60;

#[derive(Clone)]
pub struct NushellExecutor;

/// Get default timeout from environment variable or built-in default
fn get_default_timeout() -> u64 {
    env::var("MCP_NU_MCP_TIMEOUT")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(DEFAULT_TIMEOUT_SECS)
}

#[async_trait]
impl CommandExecutor for NushellExecutor {
    async fn execute(
        &self,
        command: &str,
        working_dir: &Path,
        timeout_secs: Option<u64>,
    ) -> Result<(String, String), String> {
        // Priority: parameter > env var > built-in default (60s)
        let timeout_duration =
            Duration::from_secs(timeout_secs.unwrap_or_else(get_default_timeout));

        let cmd_future = Command::new("nu")
            .arg("-c")
            .arg(command)
            .current_dir(working_dir)
            .stdin(Stdio::null()) // Prevent blocking on stdin
            .output();

        // Apply timeout wrapper
        let output = timeout(timeout_duration, cmd_future)
            .await
            .map_err(|_| {
                format!(
                    "Command timed out after {} seconds",
                    timeout_duration.as_secs()
                )
            })?
            .map_err(|e| e.to_string())?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        Ok((stdout, stderr))
    }
}
