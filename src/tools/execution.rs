use anyhow::{Context, Result, anyhow};
use async_trait::async_trait;
use tokio::process::Command;

use super::ExtensionTool;

#[async_trait]
pub trait ToolExecutor: Send + Sync {
    async fn execute_tool(
        &self,
        extension: &ExtensionTool,
        tool_name: &str,
        args: &str,
    ) -> Result<String>;
}

pub struct NushellToolExecutor;

#[async_trait]
impl ToolExecutor for NushellToolExecutor {
    async fn execute_tool(
        &self,
        extension: &ExtensionTool,
        tool_name: &str,
        args: &str,
    ) -> Result<String> {
        let mod_file = extension.module_path.join("mod.nu");

        let output = Command::new("nu")
            .arg(&mod_file)
            .arg("call-tool")
            .arg(tool_name)
            .arg(args)
            .output()
            .await
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
