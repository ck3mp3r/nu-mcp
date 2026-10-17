use super::formatter::ResultFormatter;
use crate::config::Config;
use crate::execution::CommandExecutor;
use crate::tools::{ExtensionTool, NushellToolExecutor, ToolExecutor};
use rmcp::model::CallToolRequestParams;
use rmcp::{
    model::{CallToolResult, ErrorData},
    serde_json,
};
use std::{env, path::PathBuf};

#[derive(Clone)]
pub struct ToolRouter<S, T = NushellToolExecutor>
where
    S: CommandExecutor,
    T: ToolExecutor,
{
    pub config: Config,
    pub extensions: Vec<ExtensionTool>,
    pub stateless_executor: S,
    pub tool_executor: T,
}

impl<S, T> ToolRouter<S, T>
where
    S: CommandExecutor,
    T: ToolExecutor,
{
    pub fn new(
        config: Config,
        extensions: Vec<ExtensionTool>,
        stateless_executor: S,
        tool_executor: T,
    ) -> Self {
        Self {
            config,
            extensions,
            stateless_executor,
            tool_executor,
        }
    }

    pub async fn route_call(
        &self,
        request: CallToolRequestParams,
    ) -> Result<CallToolResult, ErrorData> {
        let tool_name = request.name.clone();
        match tool_name.as_ref() {
            "run" => self.handle_run(request).await,
            tool_name => self.handle_extension_tool(request, tool_name).await,
        }
    }

    async fn handle_run(
        &self,
        request: CallToolRequestParams,
    ) -> Result<CallToolResult, ErrorData> {
        let args = request.arguments.as_ref();

        let command = args
            .and_then(|args| args.get("command"))
            .and_then(|v| v.as_str())
            .unwrap_or("version");

        // Extract optional timeout parameter
        let timeout_secs = args
            .and_then(|args| args.get("timeout_seconds"))
            .and_then(|v| v.as_u64());

        // Determine working directory
        let work_dir = determine_working_directory(&self.config.sandbox_directories)
            .map_err(|e| ErrorData::internal_error(e, None))?;

        // Execute using stateless executor (concurrent)
        let (stdout, stderr) = self
            .stateless_executor
            .execute(command, &work_dir, timeout_secs)
            .await
            .map_err(|e| ErrorData::internal_error(e, None))?;

        Ok(ResultFormatter::success_with_stderr(stdout, stderr))
    }

    async fn handle_extension_tool(
        &self,
        request: CallToolRequestParams,
        tool_name: &str,
    ) -> Result<CallToolResult, ErrorData> {
        // Look for extension tool
        if let Some(extension) = self
            .extensions
            .iter()
            .find(|e| e.tool_definition.name.as_ref() == tool_name)
        {
            // Convert arguments to JSON string
            let args_json = match &request.arguments {
                Some(args) => serde_json::to_string(args)
                    .map_err(|e| ErrorData::internal_error(e.to_string(), None))?,
                None => "{}".to_string(),
            };

            // Execute extension tool (timeout=None for now, tools don't expose it yet)
            match self
                .tool_executor
                .execute_tool(extension, tool_name, &args_json, None)
                .await
            {
                Ok(output) => Ok(ResultFormatter::success(output)),
                Err(e) => ResultFormatter::error(e.to_string()),
            }
        } else {
            ResultFormatter::invalid_request(format!("Unknown tool: {}", request.name))
        }
    }
}

/// Determine the working directory for command execution
/// Returns a directory that is within one of the allowed sandbox directories
fn determine_working_directory(sandboxes: &[PathBuf]) -> Result<PathBuf, String> {
    if sandboxes.is_empty() {
        return Err("No sandbox directories configured".to_string());
    }

    // Try to use current directory if it's within any sandbox
    if let Ok(cwd) = env::current_dir() {
        for sandbox in sandboxes {
            if let Ok(canonical_sandbox) = sandbox.canonicalize()
                && let Ok(canonical_cwd) = cwd.canonicalize()
                && canonical_cwd.starts_with(&canonical_sandbox)
            {
                return Ok(cwd);
            }
        }
    }

    // If we get here, current directory is not in any sandbox
    // Since current directory should always be in the sandboxes list (added by main.rs),
    // this should only happen if current_dir() failed or sandboxes are misconfigured
    Err("Current directory could not be determined or is not in sandbox list".to_string())
}

#[cfg(test)]
#[path = "../../test/mcp/router_working_dir.rs"]
mod working_dir_tests;
