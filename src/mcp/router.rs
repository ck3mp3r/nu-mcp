use super::formatter::ResultFormatter;
use crate::config::Config;
use crate::execution::CommandExecutor;
use crate::security::{PathCache, validate_path_safety_with_cache};
use crate::tools::{ExtensionTool, NushellToolExecutor, ToolExecutor};
use rmcp::model::CallToolRequestParams;
use rmcp::{
    model::{CallToolResult, ErrorData},
    serde_json,
};
use std::{env, path::PathBuf, sync::Arc};
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct ToolRouter<S, P, T = NushellToolExecutor>
where
    S: CommandExecutor,
    P: CommandExecutor,
    T: ToolExecutor,
{
    pub config: Config,
    pub extensions: Vec<ExtensionTool>,
    pub stateless_executor: S,
    pub persistent_executor: P,
    pub tool_executor: T,
    /// Path cache injected as dependency (Arc<RwLock> allows concurrent reads)
    path_cache: Arc<RwLock<PathCache>>,
}

impl<S, P, T> ToolRouter<S, P, T>
where
    S: CommandExecutor,
    P: CommandExecutor,
    T: ToolExecutor,
{
    pub fn new(
        config: Config,
        extensions: Vec<ExtensionTool>,
        stateless_executor: S,
        persistent_executor: P,
        tool_executor: T,
        path_cache: Arc<RwLock<PathCache>>,
    ) -> Self {
        Self {
            config,
            extensions,
            stateless_executor,
            persistent_executor,
            tool_executor,
            path_cache,
        }
    }

    pub async fn route_call(
        &self,
        request: CallToolRequestParams,
    ) -> Result<CallToolResult, ErrorData> {
        let tool_name = request.name.clone();
        match tool_name.as_ref() {
            "run" => self.handle_run(request).await,
            "shell" => self.handle_shell(request).await,
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

        // Validate command for path safety (with injected cache)
        let validation_result = {
            let mut cache = self.path_cache.write().await;
            validate_path_safety_with_cache(command, &self.config.sandbox_directories, &mut cache)
        };

        if let Err(msg) = validation_result {
            return ResultFormatter::invalid_request(msg);
        }

        // Execute using stateless executor (concurrent)
        let (stdout, stderr) = self
            .stateless_executor
            .execute(command, &work_dir, timeout_secs)
            .await
            .map_err(|e| ErrorData::internal_error(e, None))?;

        Ok(ResultFormatter::success_with_stderr(stdout, stderr))
    }

    async fn handle_shell(
        &self,
        request: CallToolRequestParams,
    ) -> Result<CallToolResult, ErrorData> {
        let args = request.arguments.as_ref();

        let command = args
            .and_then(|args| args.get("command"))
            .and_then(|v| v.as_str())
            .unwrap_or("version");

        // Trace to file for debugging (only when MCP_PTY_TRACE is set)
        if std::env::var("MCP_PTY_TRACE").is_ok()
            && let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/pty_trace.log")
        {
            use std::io::Write;
            let _ = writeln!(f, "ROUTER: handle_shell command={:?}", command);
        }

        // Check for reset parameter — recreate shell before executing
        let reset = args
            .and_then(|args| args.get("reset"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false);

        if reset {
            self.persistent_executor
                .reset()
                .await
                .map_err(|e| ErrorData::internal_error(e, None))?;
        }

        // Extract optional timeout parameter
        let timeout_secs = args
            .and_then(|args| args.get("timeout_seconds"))
            .and_then(|v| v.as_u64());

        // Determine working directory
        let work_dir = determine_working_directory(&self.config.sandbox_directories)
            .map_err(|e| ErrorData::internal_error(e, None))?;

        // Validate command for path safety (with injected cache)
        // Use write lock - async-aware, no poisoning possible
        let validation_result = {
            let mut cache = self.path_cache.write().await;
            validate_path_safety_with_cache(command, &self.config.sandbox_directories, &mut cache)
        };

        if let Err(msg) = validation_result {
            if std::env::var("MCP_PTY_TRACE").is_ok()
                && let Ok(mut f) = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open("/tmp/pty_trace.log")
            {
                use std::io::Write;
                let _ = writeln!(f, "ROUTER: path validation REJECTED: {:?}", msg);
            }
            return ResultFormatter::invalid_request(msg);
        }

        let (stdout, stderr) = self
            .persistent_executor
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
