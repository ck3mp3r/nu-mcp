use super::formatter::ResultFormatter;
use crate::config::Config;
use crate::execution::{CommandExecutor, NushellExecutor};
use crate::security::validate_path_safety;
use crate::tools::{ExtensionTool, NushellToolExecutor, ToolExecutor};
use rmcp::model::{CallToolRequestParam, CallToolResult, ErrorData};
use rmcp::serde_json;
use std::env;

#[derive(Clone)]
pub struct ToolRouter<C = NushellExecutor, T = NushellToolExecutor>
where
    C: CommandExecutor,
    T: ToolExecutor,
{
    pub config: Config,
    pub extensions: Vec<ExtensionTool>,
    pub executor: C,
    pub tool_executor: T,
}

impl<C, T> ToolRouter<C, T>
where
    C: CommandExecutor,
    T: ToolExecutor,
{
    pub fn new(
        config: Config,
        extensions: Vec<ExtensionTool>,
        executor: C,
        tool_executor: T,
    ) -> Self {
        Self {
            config,
            extensions,
            executor,
            tool_executor,
        }
    }

    pub async fn route_call(
        &self,
        request: CallToolRequestParam,
    ) -> Result<CallToolResult, ErrorData> {
        let tool_name = request.name.clone();
        match tool_name.as_ref() {
            "run-nushell" => self.handle_run_nushell(request).await,
            tool_name => self.handle_extension_tool(request, tool_name).await,
        }
    }

    async fn handle_run_nushell(
        &self,
        request: CallToolRequestParam,
    ) -> Result<CallToolResult, ErrorData> {
        let command = request
            .arguments
            .as_ref()
            .and_then(|args| args.get("command"))
            .and_then(|v| v.as_str())
            .unwrap_or("version");

        // Determine sandbox directory (use configured sandbox_directory or current working directory)
        let sandbox_dir = match &self.config.sandbox_directory {
            Some(dir) => dir.clone(),
            None => {
                env::current_dir().map_err(|e| ErrorData::internal_error(e.to_string(), None))?
            }
        };

        // Validate command for path safety
        if let Err(msg) = validate_path_safety(command, &sandbox_dir) {
            return ResultFormatter::invalid_request(msg);
        }

        let (stdout, stderr) = self
            .executor
            .execute(command, &sandbox_dir)
            .await
            .map_err(|e| ErrorData::internal_error(e, None))?;

        Ok(ResultFormatter::success_with_stderr(stdout, stderr))
    }

    async fn handle_extension_tool(
        &self,
        request: CallToolRequestParam,
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

            // Execute extension tool
            match self
                .tool_executor
                .execute_tool(extension, tool_name, &args_json)
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
