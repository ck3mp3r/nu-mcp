use anyhow::{Context, Result, anyhow};
use async_trait::async_trait;
use std::{env, time::Duration};
use tokio::process::Command;
use tokio::time::timeout;

use super::ExtensionTool;

const DEFAULT_TOOL_TIMEOUT_SECS: u64 = 60;

/// Get default timeout from environment variable or built-in default
fn get_default_tool_timeout() -> u64 {
    env::var("MCP_NU_MCP_TIMEOUT")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(DEFAULT_TOOL_TIMEOUT_SECS)
}

#[async_trait]
pub trait ToolExecutor: Send + Sync {
    async fn execute_tool(
        &self,
        extension: &ExtensionTool,
        tool_name: &str,
        args: &str,
        timeout_secs: Option<u64>,
    ) -> Result<String>;
}

#[derive(Clone)]
pub struct NushellToolExecutor;

#[async_trait]
impl ToolExecutor for NushellToolExecutor {
    async fn execute_tool(
        &self,
        extension: &ExtensionTool,
        tool_name: &str,
        args: &str,
        timeout_secs: Option<u64>,
    ) -> Result<String> {
        let mod_file = extension.module_path.join("mod.nu");

        // Priority: parameter > env var > built-in default (60s)
        let timeout_duration =
            Duration::from_secs(timeout_secs.unwrap_or_else(get_default_tool_timeout));

        let cmd_future = Command::new("nu")
            .arg(&mod_file)
            .arg("call-tool")
            .arg(tool_name)
            .arg(args)
            .output();

        let output = timeout(timeout_duration, cmd_future)
            .await
            .map_err(|_| {
                anyhow!(
                    "Tool '{}' timed out after {} seconds",
                    tool_name,
                    timeout_duration.as_secs()
                )
            })?
            .with_context(|| {
                format!(
                    "Failed to execute tool '{}' from {}",
                    tool_name,
                    mod_file.display()
                )
            })?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Tool '{}' execution failed: {stderr}", tool_name));
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}
