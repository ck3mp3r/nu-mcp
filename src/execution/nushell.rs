use super::CommandExecutor;
use async_trait::async_trait;
use std::path::Path;
use tokio::process::Command;

#[derive(Clone)]
pub struct NushellExecutor;

#[async_trait]
impl CommandExecutor for NushellExecutor {
    async fn execute(&self, command: &str, working_dir: &Path) -> Result<(String, String), String> {
        let output = Command::new("nu")
            .arg("-c")
            .arg(command)
            .current_dir(working_dir)
            .output()
            .await
            .map_err(|e| e.to_string())?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        Ok((stdout, stderr))
    }
}
