use rmcp::model::Tool;
use rmcp::serde_json::{Map, Value};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::process::Command;

#[derive(Debug, Clone)]
pub struct ExtensionTool {
    pub script_path: PathBuf,
    pub tool_definition: Tool,
}

/// Discover tools from nushell scripts in the given directory
pub async fn discover_tools(tools_dir: &PathBuf) -> Result<Vec<ExtensionTool>, Box<dyn std::error::Error>> {
    let mut extension_tools = Vec::new();
    
    // Check if directory exists
    if !tools_dir.exists() || !tools_dir.is_dir() {
        return Ok(extension_tools);
    }

    // Read directory entries
    let mut dir = tokio::fs::read_dir(tools_dir).await?;
    
    while let Some(entry) = dir.next_entry().await? {
        let path = entry.path();
        
        // Only process .nu files
        if path.extension().and_then(|s| s.to_str()) == Some("nu") {
            match discover_tools_from_script(&path).await {
                Ok(mut tools) => extension_tools.append(&mut tools),
                Err(e) => eprintln!("Warning: Failed to discover tools from {}: {}", path.display(), e),
            }
        }
    }
    
    Ok(extension_tools)
}

/// Discover tools from a single nushell script
async fn discover_tools_from_script(script_path: &PathBuf) -> Result<Vec<ExtensionTool>, Box<dyn std::error::Error>> {
    // Execute the script with list-tools subcommand
    let output = Command::new("nu")
        .arg(script_path)
        .arg("list-tools")
        .output()
        .await?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Script execution failed: {}", stderr).into());
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let tool_definitions: Vec<ToolDefinition> = serde_json::from_str(&stdout)?;
    
    let mut extension_tools = Vec::new();
    
    for def in tool_definitions {
        let tool = Tool {
            name: def.name.into(),
            description: def.description.map(|d| d.into()),
            input_schema: Arc::new(def.input_schema),
            annotations: None,
        };
        
        extension_tools.push(ExtensionTool {
            script_path: script_path.clone(),
            tool_definition: tool,
        });
    }
    
    Ok(extension_tools)
}

/// Execute an extension tool
pub async fn execute_extension_tool(
    extension: &ExtensionTool,
    tool_name: &str,
    args: &str,
) -> Result<String, Box<dyn std::error::Error>> {
    let output = Command::new("nu")
        .arg(&extension.script_path)
        .arg("call-tool")
        .arg(tool_name)
        .arg(args)
        .output()
        .await?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Tool execution failed: {}", stderr).into());
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Tool definition structure for JSON parsing
#[derive(serde::Deserialize)]
struct ToolDefinition {
    name: String,
    description: Option<String>,
    input_schema: Map<String, Value>,
}