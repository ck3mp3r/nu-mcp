use crate::filter::{Config, is_command_allowed};
use rmcp::{
    RoleServer, ServiceExt,
    handler::server::ServerHandler,
    model::*,
    serde_json::{Map, Value},
    service::RequestContext,
    transport,
};
use std::env;
use std::sync::Arc;
use tokio::process::Command;

#[derive(Clone)]
pub struct NushellTool {
    pub config: Config,
}

impl ServerHandler for NushellTool {
    fn get_info(&self) -> ServerInfo {
        let mut instructions = String::from("MCP server exposing Nushell commands.\n");

        instructions.push_str("Allowed commands (always permitted):\n");
        if self.config.allowed_commands.is_empty() {
            instructions.push_str("  (none specified)\n");
        } else {
            for cmd in &self.config.allowed_commands {
                instructions.push_str(&format!("  - {}\n", cmd));
            }
        }

        instructions.push_str("Denied commands (blocked unless in allowed list):\n");
        if self.config.denied_commands.is_empty() {
            instructions.push_str("  (none specified)\n");
        } else {
            for cmd in &self.config.denied_commands {
                instructions.push_str(&format!("  - {}\n", cmd));
            }
        }

        instructions.push_str(&format!(
            "Sudo allowed: {}\n",
            if self.config.allow_sudo { "yes" } else { "no" }
        ));

        ServerInfo {
            instructions: Some(instructions),
            ..Default::default()
        }
    }

    async fn list_tools(
        &self,
        _request: Option<PaginatedRequestParam>,
        _context: RequestContext<RoleServer>,
    ) -> Result<ListToolsResult, ErrorData> {
        // Create the input schema manually
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

        let tools = vec![Tool {
            name: "run_nushell".into(),
            description: Some("Run a Nushell command and return its output".into()),
            input_schema: Arc::new(schema),
            annotations: None,
        }];

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

                // Validate command for security
                fn is_command_safe(command: &str) -> bool {
                    // Reject absolute paths (Unix)
                    if command.contains(" /") || command.starts_with('/') {
                        return false;
                    }
                    // Reject absolute paths (Windows)
                    if command.contains(":\\") || command.contains(":/") {
                        return false;
                    }
                    // Reject parent directory traversal
                    if command.contains("../")
                        || command.contains("..\\")
                        || command.contains(".. ")
                        || command.contains(" ..")
                    {
                        return false;
                    }
                    true
                }

                if !is_command_safe(command) {
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
            _ => Err(ErrorData::invalid_request(
                format!("Unknown tool: {}", request.name),
                None,
            )),
        }
    }
}

pub async fn run_server(config: Config) -> Result<(), Box<dyn std::error::Error>> {
    let tool = NushellTool { config };
    let service = tool.serve(transport::stdio()).await?;
    service.waiting().await?;
    Ok(())
}
