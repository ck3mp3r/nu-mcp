use super::CommandExecutor;
use std::{path::Path, process::Stdio, time::Duration};
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

        // Spawn child process
        let child = Command::new("nu")
            .arg("-c")
            .arg(command)
            .current_dir(working_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true) // Ensure child is killed if future is dropped/cancelled
            .spawn()
            .map_err(|e| format!("Failed to spawn nu process: {}", e))?;

        // Wait for process with timeout - child is consumed by wait_with_output
        let output_result = timeout(timeout_duration, child.wait_with_output()).await;

        match output_result {
            Ok(Ok(output)) => {
                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                let stderr = String::from_utf8_lossy(&output.stderr).to_string();
                Ok((stdout, stderr))
            }
            Ok(Err(e)) => Err(e.to_string()),
            Err(_) => {
                // Timeout occurred - child should be killed by kill_on_drop
                // when the timeout future is dropped/cancelled
                Err(format!(
                    "Command timed out after {} seconds",
                    timeout_duration.as_secs()
                ))
            }
        }
    }
}
