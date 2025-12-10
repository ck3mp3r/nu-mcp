use super::formatter::ResultFormatter;
use crate::config::Config;
use crate::execution::{CommandExecutor, NushellExecutor};
use crate::security::validate_path_safety;
use crate::tools::{ExtensionTool, NushellToolExecutor, ToolExecutor};
use rmcp::model::{CallToolRequestParam, CallToolResult, ErrorData};
use rmcp::serde_json;
use std::{env, path::PathBuf};

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
            "run_nushell" => self.handle_run_nushell(request).await,
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

        // Determine working directory
        let work_dir = determine_working_directory(&self.config.sandbox_directories)
            .map_err(|e| ErrorData::internal_error(e, None))?;

        // Validate command for path safety
        if let Err(msg) = validate_path_safety(command, &self.config.sandbox_directories) {
            return ResultFormatter::invalid_request(msg);
        }

        let (stdout, stderr) = self
            .executor
            .execute(command, &work_dir)
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

/// Determine the working directory for command execution
/// Returns a directory that is within one of the allowed sandbox directories
fn determine_working_directory(sandboxes: &[PathBuf]) -> Result<PathBuf, String> {
    if sandboxes.is_empty() {
        return Err("No sandbox directories configured".to_string());
    }

    // Try to use current directory if it's within any sandbox
    if let Ok(cwd) = env::current_dir() {
        for sandbox in sandboxes {
            if let Ok(canonical_sandbox) = sandbox.canonicalize() {
                if let Ok(canonical_cwd) = cwd.canonicalize() {
                    if canonical_cwd.starts_with(&canonical_sandbox) {
                        return Ok(cwd);
                    }
                }
            }
        }
    }

    // If we get here, current directory is not in any sandbox
    // Since current directory should always be in the sandboxes list (added by main.rs),
    // this should only happen if current_dir() failed or sandboxes are misconfigured
    Err("Current directory could not be determined or is not in sandbox list".to_string())
}

#[cfg(test)]
mod router_test {
    use super::*;

    #[test]
    fn test_determine_working_directory_returns_current_dir_when_in_sandbox() {
        // If current directory IS in a sandbox, it should return current directory
        let cwd = env::current_dir().unwrap();

        // Use the actual current directory as one of the sandboxes
        let sandboxes = vec![cwd.clone()];
        let result = determine_working_directory(&sandboxes);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), cwd);
    }

    #[test]
    fn test_determine_working_directory_skips_invalid_sandboxes() {
        // Should skip invalid sandbox paths and check remaining valid ones
        let sandboxes = vec![
            PathBuf::from("/nonexistent/path/that/does/not/exist"),
            PathBuf::from("/another/invalid/path"),
            PathBuf::from("/tmp"),
        ];

        let result = determine_working_directory(&sandboxes);

        let cwd = env::current_dir().unwrap();
        if cwd.starts_with("/tmp") || cwd.starts_with("/private/tmp") {
            // If we're in /tmp, should succeed
            assert!(result.is_ok());
        } else {
            // If not in /tmp, should error since other sandboxes are invalid
            assert!(result.is_err());
            assert!(
                result
                    .unwrap_err()
                    .contains("Current directory could not be determined")
            );
        }
    }

    #[test]
    fn test_determine_working_directory_with_empty_sandboxes() {
        let sandboxes: Vec<PathBuf> = vec![];

        let result = determine_working_directory(&sandboxes);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("No sandbox directories"));
    }

    #[test]
    fn test_determine_working_directory_with_additional_sandboxes() {
        // Current directory PLUS additional sandboxes (realistic scenario from main.rs)
        let cwd = env::current_dir().unwrap();
        let sandboxes = vec![
            cwd.clone(),
            PathBuf::from("/tmp"),
            PathBuf::from("/nix/store"),
        ];

        let result = determine_working_directory(&sandboxes);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), cwd);
    }
}
