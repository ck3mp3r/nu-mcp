use rmcp::{
    RoleServer, ServiceExt,
    handler::server::ServerHandler,
    model::*,
    serde_json::{Map, Value},
    service::RequestContext,
    transport,
};
use std::sync::Arc;
use tokio::process::Command;

#[derive(Clone)]
pub struct NushellTool;

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
                // Extract the command parameter
                let command = request
                    .arguments
                    .as_ref()
                    .and_then(|args| args.get("command"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("version");

                let output = Command::new("nu")
                    .arg("-c")
                    .arg(command)
                    .output()
                    .await
                    .map_err(|e| ErrorData::internal_error(e.to_string(), None))?;

                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                let stderr = String::from_utf8_lossy(&output.stderr).to_string();

                let mut content = vec![Content::text(stdout)];
                if !stderr.is_empty() {
                    content.push(Content::text(format!("stderr: {}", stderr)));
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
    let tool = NushellTool;
    let service = tool.serve(transport::stdio()).await?;
    service.waiting().await?;
    Ok(())
}
