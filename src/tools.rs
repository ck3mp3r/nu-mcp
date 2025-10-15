use rmcp::model::Tool;
use rmcp::serde_json::{Map, Value};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::process::Command;

#[derive(Debug, Clone)]
pub struct ExtensionTool {
    pub module_path: PathBuf,
    pub tool_definition: Tool,
}

/// Discover tools from nushell modules in the given directory
pub async fn discover_tools(
    tools_dir: &PathBuf,
) -> Result<Vec<ExtensionTool>, Box<dyn std::error::Error>> {
    let mut extension_tools = Vec::new();

    // Check if directory exists
    if !tools_dir.exists() || !tools_dir.is_dir() {
        return Ok(extension_tools);
    }

    // Check if the tools_dir itself is a module directory (contains mod.nu)
    let mod_file = tools_dir.join("mod.nu");
    if mod_file.exists() {
        // The tools_dir is itself a module directory, process it directly
        match discover_tools_from_module(tools_dir).await {
            Ok(mut tools) => extension_tools.append(&mut tools),
            Err(e) => eprintln!(
                "Warning: Failed to discover tools from {}: {}",
                tools_dir.display(),
                e
            ),
        }
        return Ok(extension_tools);
    }

    // Otherwise, treat tools_dir as a parent directory containing module subdirectories
    let mut dir = tokio::fs::read_dir(tools_dir).await?;

    while let Some(entry) = dir.next_entry().await? {
        let path = entry.path();

        // Only process directories
        if path.is_dir() {
            let mod_file = path.join("mod.nu");
            if mod_file.exists() {
                match discover_tools_from_module(&path).await {
                    Ok(mut tools) => extension_tools.append(&mut tools),
                    Err(e) => eprintln!(
                        "Warning: Failed to discover tools from {}: {}",
                        path.display(),
                        e
                    ),
                }
            }
        }
    }

    Ok(extension_tools)
}

/// Discover tools from a nushell module
async fn discover_tools_from_module(
    module_path: &PathBuf,
) -> Result<Vec<ExtensionTool>, Box<dyn std::error::Error>> {
    let mod_file = module_path.join("mod.nu");
    
    // Execute the mod.nu file with list-tools subcommand
    let output = Command::new("nu")
        .arg(&mod_file)
        .arg("list-tools")
        .output()
        .await?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Module execution failed: {}", stderr).into());
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
            title: None,
            output_schema: None,
            icons: None,
        };

        extension_tools.push(ExtensionTool {
            module_path: module_path.clone(),
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
    let mod_file = extension.module_path.join("mod.nu");
    
    let output = Command::new("nu")
        .arg(&mod_file)
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
