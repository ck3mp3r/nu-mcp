use clap::Parser;
use rmcp::{
    RoleServer, ServiceExt,
    handler::server::ServerHandler,
    model::*,
    serde_json::{Map, Value},
    service::RequestContext,
    transport,
};
use serde::Deserialize;
use std::env;
use std::sync::Arc;
use tokio::process::Command;

#[derive(Debug, Clone, Deserialize, Default)]
pub struct Config {
    pub denied_commands: Vec<String>,
    pub allowed_commands: Vec<String>,
    pub allow_sudo: bool,
}

#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Cli {
    /// Comma-separated list of denied commands
    #[arg(long, value_delimiter = ',')]
    denied_cmds: Option<Vec<String>>,

    /// Comma-separated list of allowed commands (takes precedence over denied)
    #[arg(long, value_delimiter = ',')]
    allowed_cmds: Option<Vec<String>>,

    /// Allow sudo (default: false)
    #[arg(long, default_value_t = false)]
    allow_sudo: bool,
}

#[derive(Clone)]
pub struct NushellTool {
    config: Config,
}

impl ServerHandler for NushellTool {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            instructions: Some("MCP server exposing Nushell commands".into()),
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

                // Allowed commands take precedence over denied commands
                let first_word = command.split_whitespace().next().unwrap_or("");
                if !self
                    .config
                    .allowed_commands
                    .iter()
                    .any(|ac| first_word == ac)
                    && self
                        .config
                        .denied_commands
                        .iter()
                        .any(|dc| first_word == dc)
                {
                    return Err(ErrorData::invalid_request(
                        format!("Command '{first_word}' is denied by server configuration"),
                        None,
                    ));
                }

                // Check sudo
                if !self.config.allow_sudo && first_word == "sudo" {
                    return Err(ErrorData::invalid_request(
                        "Use of 'sudo' is not permitted by server configuration".to_string(),
                        None,
                    ));
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

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    let default_denied = vec![
        "rm".to_string(),
        "shutdown".to_string(),
        "reboot".to_string(),
        "poweroff".to_string(),
        "halt".to_string(),
        "mkfs".to_string(),
        "dd".to_string(),
        "chmod".to_string(),
        "chown".to_string(),
    ];

    let config = Config {
        denied_commands: cli.denied_cmds.unwrap_or(default_denied),
        allowed_commands: cli.allowed_cmds.unwrap_or_default(),
        allow_sudo: cli.allow_sudo,
    };

    let tool = NushellTool { config };
    let service = tool.serve(transport::stdio()).await?;
    service.waiting().await?;
    Ok(())
}
