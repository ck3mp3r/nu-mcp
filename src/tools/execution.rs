use super::ExtensionTool;
use async_trait::async_trait;
use tokio::process::Command;

#[async_trait]
pub trait ToolExecutor: Send + Sync {
    async fn execute_tool(
        &self,
        extension: &ExtensionTool,
        tool_name: &str,
        args: &str,
    ) -> Result<String, Box<dyn std::error::Error>>;
}

pub struct NushellToolExecutor;

#[async_trait]
impl ToolExecutor for NushellToolExecutor {
    async fn execute_tool(
        &self,
        extension: &ExtensionTool,
        tool_name: &str,
        args: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let mod_file = extension.module_path.join("mod.nu");

        let output = Command::new("nu")
            .arg(&mod_file)
            .arg("call-tool")
            .arg(tool_name)
            .arg(args)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Tool execution failed: {stderr}").into());
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}
