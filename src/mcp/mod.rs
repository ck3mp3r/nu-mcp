pub use self::router::ToolRouter;
use std::{env, sync::Arc};

use anyhow::Result;

use rmcp::{
    RoleServer, ServiceExt,
    handler::server::ServerHandler,
    model::*,
    serde_json::{Map, Value},
    service::RequestContext,
    transport,
};

use crate::{
    config::Config,
    execution::{CommandExecutor, NushellExecutor},
    tools::{NushellToolExecutor, ToolExecutor, discover_tools},
};

const RUN_NUSHELL_DESCRIPTION: &str = include_str!("../../docs/run_nushell_description.txt");

#[derive(Clone)]
pub struct NushellTool<C = NushellExecutor, T = NushellToolExecutor>
where
    C: CommandExecutor + 'static,
    T: ToolExecutor + 'static,
{
    pub router: ToolRouter<C, T>,
}

impl<C, T> ServerHandler for NushellTool<C, T>
where
    C: CommandExecutor + 'static,
    T: ToolExecutor + 'static,
{
    fn get_info(&self) -> InitializeResult {
        let mut instructions = String::from("MCP server exposing Nushell commands.\n");

        instructions.push_str("Security: Commands execute in sandbox directories.\n");
        instructions.push_str("- Path traversal escaping sandboxes is blocked\n");
        instructions.push_str("- Absolute paths outside sandboxes are blocked\n");

        if self.router.config.sandbox_directories.is_empty() {
            instructions.push_str("- Sandbox: current working directory\n");
        } else {
            instructions.push_str("- Accessible directories:\n");
            if let Ok(cwd) = std::env::current_dir() {
                // Try to match cwd with one of the sandboxes
                let cwd_canonical = cwd.canonicalize().ok();
                for sandbox_dir in &self.router.config.sandbox_directories {
                    let is_cwd = if let Some(ref cwd_can) = cwd_canonical {
                        sandbox_dir.canonicalize().ok().as_ref() == Some(cwd_can)
                    } else {
                        false
                    };

                    if is_cwd {
                        instructions.push_str(&format!(
                            "  - {} (current directory)\n",
                            sandbox_dir.display()
                        ));
                    } else {
                        instructions.push_str(&format!("  - {}\n", sandbox_dir.display()));
                    }
                }
            } else {
                // Can't determine cwd, just list sandboxes
                for sandbox_dir in &self.router.config.sandbox_directories {
                    instructions.push_str(&format!("  - {}\n", sandbox_dir.display()));
                }
            }
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
        for extension in &self.router.extensions {
            tools.push(extension.tool_definition.clone());
        }

        // Add run_nushell tool based on configuration:
        // - If no tools directory: include by default
        // - If tools directory exists: only include if explicitly enabled
        let should_include_run_nushell = match &self.router.config.tools_dir {
            None => true, // No tools dir = include run_nushell by default
            Some(_) => self.router.config.enable_run_nushell, // Tools dir exists = only if explicitly enabled
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

            // Build description with sandbox directory info
            let sandbox_note = if self.router.config.sandbox_directories.is_empty() {
                "\n\nSandbox: current working directory".to_string()
            } else {
                let mut note = String::from("\n\nAccessible directories:");
                if let Ok(cwd) = std::env::current_dir() {
                    let cwd_canonical = cwd.canonicalize().ok();
                    for dir in &self.router.config.sandbox_directories {
                        let is_cwd = if let Some(ref cwd_can) = cwd_canonical {
                            dir.canonicalize().ok().as_ref() == Some(cwd_can)
                        } else {
                            false
                        };

                        if is_cwd {
                            note.push_str(&format!("\n- {} (current directory)", dir.display()));
                        } else {
                            note.push_str(&format!("\n- {}", dir.display()));
                        }
                    }
                } else {
                    for dir in &self.router.config.sandbox_directories {
                        note.push_str(&format!("\n- {}", dir.display()));
                    }
                }
                note
            };

            let description = format!("{}{}", RUN_NUSHELL_DESCRIPTION, sandbox_note);

            tools.push(Tool {
                name: "run_nushell".into(),
                description: Some(description.into()),
                input_schema: Arc::new(schema),
                annotations: None,
                title: Some("Run Nushell Command".to_string()),
                output_schema: None,
                icons: None,
                meta: None,
            });
        }

        Ok(ListToolsResult {
            tools,
            next_cursor: None,
            meta: None,
        })
    }

    async fn call_tool(
        &self,
        request: CallToolRequestParam,
        _context: RequestContext<RoleServer>,
    ) -> Result<CallToolResult, ErrorData> {
        self.router.route_call(request).await
    }
}

pub async fn run_server(config: Config) -> Result<()> {
    // Discover extension tools if tools_dir is provided
    let extensions = if let Some(ref tools_dir) = config.tools_dir {
        discover_tools(tools_dir).await?
    } else {
        Vec::new()
    };

    let executor = NushellExecutor;
    let tool_executor = NushellToolExecutor;

    // Create path cache (session-scoped, lives for server lifetime)
    let path_cache = std::sync::Arc::new(std::sync::Mutex::new(crate::security::PathCache::new()));

    let router = ToolRouter::new(config, extensions, executor, tool_executor, path_cache);
    let tool = NushellTool { router };
    let service = tool.serve(transport::stdio()).await?;
    service.waiting().await?;
    Ok(())
}

pub mod formatter;
pub mod router;

#[cfg(test)]
mod formatter_test;
#[cfg(test)]
mod mod_test;
#[cfg(test)]
mod router_test;
