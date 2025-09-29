use crate::filter::{Config, is_command_allowed};
use crate::tools::{ExtensionTool, execute_extension_tool, discover_tools};
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

        instructions.push_str("Allowed commands (always permitted):\n");
        if self.config.allowed_commands.is_empty() {
            instructions.push_str("  (none specified)\n");
        } else {
            for cmd in &self.config.allowed_commands {
                instructions.push_str(&format!("  - {cmd}\n"));
            }
        }

        instructions.push_str("Denied commands (blocked unless in allowed list):\n");
        if self.config.denied_commands.is_empty() {
            instructions.push_str("  (none specified)\n");
        } else {
            for cmd in &self.config.denied_commands {
                instructions.push_str(&format!("  - {cmd}\n"));
            }
        }

        instructions.push_str(&format!(
            "Sudo allowed: {}\n",
            if self.config.allow_sudo { "yes" } else { "no" }
        ));

        InitializeResult {
            protocol_version: ProtocolVersion::LATEST,
            capabilities: ServerCapabilities {
                tools: Some(ToolsCapability::default()),
                ..Default::default()
            },
            server_info: Implementation {
                name: "nu-mcp".to_string(),
                version: env!("CARGO_PKG_VERSION").to_string(),
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
            None => true,  // No tools dir = include run_nushell by default
            Some(_) => self.config.enable_run_nushell,  // Tools dir exists = only if explicitly enabled
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

                // Use testable filter function
                if let Err(msg) = is_command_allowed(&self.config, command) {
                    return Err(ErrorData::invalid_request(msg, None));
                }

                // Validate command for security (run_nushell tool only)
                let is_command_safe = |command: &str, config: &Config| -> bool {
                    // Allow URLs by checking for protocol schemes
                    let contains_url = command.contains("://") || 
                                     command.contains("http:") || 
                                     command.contains("https:") ||
                                     command.contains("ftp:") ||
                                     command.contains("ws:") ||
                                     command.contains("wss:");
                    
                    // Check path traversal protection (unless disabled)
                    if !config.disable_run_nushell_path_traversal_check
                        && (command.contains("../") ||
                           command.contains("..\\") ||
                           command.contains(".. ") ||
                           command.contains(" ..")) {
                            return false;
                        }
                    
                    // Check system directory protection (unless disabled or URL)
                    if !config.disable_run_nushell_system_dir_check && !contains_url {
                        // Reject absolute paths starting with /
                        if command.starts_with('/') {
                            return false;
                        }
                        
                        // Reject references to sensitive system directories (without trailing slash)
                        let sensitive_dirs = ["/etc", "/root", "/home", "/usr", "/var", "/sys", "/proc", "/bin", "/sbin", "/boot"];
                        for dir in &sensitive_dirs {
                            if command.contains(&format!(" {}", dir)) ||  // " /etc"
                               command.ends_with(dir) {                  // "ls /etc"
                                return false;
                            }
                        }
                        
                        // Reject Windows absolute paths
                        if command.contains(":\\") {
                            return false;
                        }
                    }
                    
                    true
                };

                if !is_command_safe(command, &self.config) {
                    return Err(ErrorData::invalid_request(
                        "Command contains forbidden path traversal or absolute path".to_string(),
                        None,
                    ));
                }

                // Restrict to current working directory
                let cwd = env::current_dir()
                    .map_err(|e| ErrorData::internal_error(e.to_string(), None))?;

                let output = Command::new("nu")
                    .arg("-c")
                    .arg(command)
                    .current_dir(&cwd)
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
                if let Some(extension) = self.extensions.iter().find(|e| e.tool_definition.name.as_ref() == tool_name) {
                    // Convert arguments to JSON string
                    let args_json = match &request.arguments {
                        Some(args) => serde_json::to_string(args)
                            .map_err(|e| ErrorData::internal_error(e.to_string(), None))?,
                        None => "{}".to_string(),
                    };

                    // Execute extension tool
                    match execute_extension_tool(extension, tool_name, &args_json).await {
                        Ok(output) => {
                            Ok(CallToolResult::success(vec![Content::text(output)]))
                        }
                        Err(e) => {
                            Err(ErrorData::internal_error(e.to_string(), None))
                        }
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
