use super::CommandExecutor;
use std::{path::Path, time::Duration};
use tokio::process::Command;
use tokio::time::timeout;

#[derive(Clone)]
pub struct NushellExecutor;

impl CommandExecutor for NushellExecutor {
    async fn execute(
        &self,
        command: &str,
        working_dir: &Path,
        timeout_secs: Option<u64>,
    ) -> Result<(String, String), String> {
        // Priority: parameter > env var > built-in default (60s)
        let timeout_duration =
            Duration::from_secs(timeout_secs.unwrap_or_else(super::get_default_timeout));

        let cmd_future = Command::new("nu")
            .arg("-c")
            .arg(command)
            .current_dir(working_dir)
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
