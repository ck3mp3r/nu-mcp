use super::formatter::ResultFormatter;
use crate::config::Config;
use crate::execution::CommandExecutor;
use crate::security::validate_path_safety;
use crate::tools::{ExtensionTool, ToolExecutor};
use rmcp::model::{CallToolRequestParam, CallToolResult, ErrorData};
use rmcp::serde_json;
use std::env;
use std::sync::Arc;

#[derive(Clone)]
pub struct ToolRouter {
    pub config: Config,
    pub extensions: Vec<ExtensionTool>,
    pub executor: Arc<dyn CommandExecutor>,
    pub tool_executor: Arc<dyn ToolExecutor>,
}

impl ToolRouter {
    pub fn new(
        config: Config,
        extensions: Vec<ExtensionTool>,
        executor: Arc<dyn CommandExecutor>,
        tool_executor: Arc<dyn ToolExecutor>,
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::execution::MockExecutor;
    use crate::tools::MockToolExecutor;
    use rmcp::model::{CallToolRequestParam, Tool};
    use rmcp::serde_json;
    use std::path::PathBuf;

    fn create_test_router() -> ToolRouter {
        let config = Config {
            tools_dir: None,
            enable_run_nushell: true,
            sandbox_directory: Some(PathBuf::from("/tmp")),
        };
        let executor = Arc::new(MockExecutor::new("test output".to_string(), "".to_string()));
        let tool_executor = Arc::new(MockToolExecutor::new("tool output".to_string()));
        ToolRouter::new(config, vec![], executor, tool_executor)
    }

    #[tokio::test]
    async fn test_router_run_nushell() {
        let router = create_test_router();

        let mut args = serde_json::Map::new();
        args.insert(
            "command".to_string(),
            serde_json::Value::String("echo hello".to_string()),
        );

        let request = CallToolRequestParam {
            name: "run_nushell".into(),
            arguments: Some(args),
        };

        let result = router.route_call(request).await;
        assert!(result.is_ok());

        let call_result = result.unwrap();
        assert!(!call_result.content.is_empty());
    }

    #[tokio::test]
    async fn test_router_unknown_tool() {
        let router = create_test_router();

        let request = CallToolRequestParam {
            name: "unknown_tool".into(),
            arguments: None,
        };

        let result = router.route_call(request).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_router_extension_tool() {
        let config = Config {
            tools_dir: None,
            enable_run_nushell: true,
            sandbox_directory: Some(PathBuf::from("/tmp")),
        };

        let extension = crate::tools::ExtensionTool {
            module_path: PathBuf::from("/test/path"),
            tool_definition: Tool {
                name: "test_tool".into(),
                description: None,
                input_schema: Arc::new(serde_json::Map::new()),
                annotations: None,
                title: None,
                output_schema: None,
                icons: None,
            },
        };

        let executor = Arc::new(MockExecutor::new("test output".to_string(), "".to_string()));
        let tool_executor = Arc::new(MockToolExecutor::new("extension output".to_string()));
        let router = ToolRouter::new(config, vec![extension], executor, tool_executor);

        let request = CallToolRequestParam {
            name: "test_tool".into(),
            arguments: None,
        };

        let result = router.route_call(request).await;
        assert!(result.is_ok());

        let call_result = result.unwrap();
        assert!(!call_result.content.is_empty());
    }
}
