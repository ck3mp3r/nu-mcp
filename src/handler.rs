use crate::filter::{Config, validate_path_safety};
use crate::tools::{ExtensionTool, discover_tools, execute_extension_tool};
use rmcp::{
    RoleServer, ServiceExt,
    handler::server::ServerHandler,
    model::*,
    serde_json::{self, Map, Value},
    service::RequestContext,
    transport,
};
use std::env;
use std::sync::Arc;
use tokio::process::Command;

#[derive(Clone)]
pub struct NushellTool {
    pub config: Config,
    pub extensions: Vec<ExtensionTool>,
}

impl ServerHandler for NushellTool {
    fn get_info(&self) -> InitializeResult {
        let mut instructions = String::from("MCP server exposing Nushell commands.\n");

        instructions.push_str("Security: Commands execute in a directory sandbox.\n");
        instructions.push_str("- Path traversal patterns (../) are blocked\n");
        instructions.push_str("- Absolute paths outside sandbox are blocked\n");

        if let Some(sandbox_dir) = &self.config.sandbox_directory {
            instructions.push_str(&format!("- Sandbox directory: {}\n", sandbox_dir.display()));
        } else {
            instructions.push_str("- Sandbox directory: current working directory\n");
        }

        InitializeResult {
            protocol_version: ProtocolVersion::LATEST,
            capabilities: ServerCapabilities {
                tools: Some(ToolsCapability::default()),
                ..Default::default()
            },
            server_info: Implementation {
                name: "nu-mcp".to_string(),
                version: env!("CARGO_PKG_VERSION").to_string(),
                title: Some("Nu MCP Server".to_string()),
                website_url: Some("https://github.com/ck3mp3r/nu-mcp".to_string()),
                icons: None,
            },
            instructions: Some(instructions),
        }
    }

    async fn list_tools(
        &self,
        _request: Option<PaginatedRequestParam>,
        _context: RequestContext<RoleServer>,
    ) -> Result<ListToolsResult, ErrorData> {
        let mut tools = Vec::new();

        // Add extension tools
        for extension in &self.extensions {
            tools.push(extension.tool_definition.clone());
        }

        // Add run_nushell tool based on configuration:
        // - If no tools directory: include by default
        // - If tools directory exists: only include if explicitly enabled
        let should_include_run_nushell = match &self.config.tools_dir {
            None => true, // No tools dir = include run_nushell by default
            Some(_) => self.config.enable_run_nushell, // Tools dir exists = only if explicitly enabled
        };

        if should_include_run_nushell {
            // Create the input schema for run_nushell tool
            let mut schema = Map::new();
            schema.insert("type".to_string(), Value::String("object".to_string()));

            let mut properties = Map::new();
            let mut command_prop = Map::new();
            command_prop.insert("type".to_string(), Value::String("string".to_string()));
            command_prop.insert(
                "description".to_string(),
                Value::String("The Nushell command to execute".to_string()),
            );
            properties.insert("command".to_string(), Value::Object(command_prop));

            schema.insert("properties".to_string(), Value::Object(properties));
            schema.insert(
                "required".to_string(),
                Value::Array(vec![Value::String("command".to_string())]),
            );

            tools.push(Tool {
                name: "run_nushell".into(),
                description: Some("Run a Nushell command and return its output".into()),
                input_schema: Arc::new(schema),
                annotations: None,
                title: Some("Run Nushell Command".to_string()),
                output_schema: None,
                icons: None,
            });
        }

        Ok(ListToolsResult {
            tools,
            next_cursor: None,
        })
    }

    async fn call_tool(
        &self,
        request: CallToolRequestParam,
        _context: RequestContext<RoleServer>,
    ) -> Result<CallToolResult, ErrorData> {
        match request.name.as_ref() {
            "run_nushell" => {
                let command = request
                    .arguments
                    .as_ref()
                    .and_then(|args| args.get("command"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("version");

                // Determine sandbox directory (use configured sandbox_directory or current working directory)
                let sandbox_dir = match &self.config.sandbox_directory {
                    Some(dir) => dir.clone(),
                    None => env::current_dir()
                        .map_err(|e| ErrorData::internal_error(e.to_string(), None))?,
                };

                // Validate command for path safety
                if let Err(msg) = validate_path_safety(command, &sandbox_dir) {
                    return Err(ErrorData::invalid_request(msg, None));
                }

                let output = Command::new("nu")
                    .arg("-c")
                    .arg(command)
                    .current_dir(&sandbox_dir)
                    .output()
                    .await
                    .map_err(|e| ErrorData::internal_error(e.to_string(), None))?;

                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                let stderr = String::from_utf8_lossy(&output.stderr).to_string();

                let mut content = vec![Content::text(stdout)];
                if !stderr.is_empty() {
                    content.push(Content::text(format!("stderr: {stderr}")));
                }

                Ok(CallToolResult::success(content))
            }
            tool_name => {
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
                    match execute_extension_tool(extension, tool_name, &args_json).await {
                        Ok(output) => Ok(CallToolResult::success(vec![Content::text(output)])),
                        Err(e) => Err(ErrorData::internal_error(e.to_string(), None)),
                    }
                } else {
                    Err(ErrorData::invalid_request(
                        format!("Unknown tool: {}", request.name),
                        None,
                    ))
                }
            }
        }
    }
}

pub async fn run_server(config: Config) -> Result<(), Box<dyn std::error::Error>> {
    // Discover extension tools if tools_dir is provided
    let extensions = if let Some(ref tools_dir) = config.tools_dir {
        discover_tools(tools_dir).await?
    } else {
        Vec::new()
    };

    let tool = NushellTool { config, extensions };
    let service = tool.serve(transport::stdio()).await?;
    service.waiting().await?;
    Ok(())
}
