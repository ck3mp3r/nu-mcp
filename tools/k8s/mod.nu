# Kubernetes MCP Server
# Model Context Protocol server for Kubernetes cluster management

use utils.nu *
use formatters.nu *
use resources.nu *
use operations.nu *

# Main entry point for MCP protocol
export def main [
    action: string
    ...args: any
] {
    match $action {
        "list-tools" => { list_tools }
        "call-tool" => { 
            if ($args | length) < 2 {
                error make {
                    msg: "call-tool requires tool name and parameters"
                }
            }
            call_tool ($args | get 0) ($args | get 1)
        }
        _ => {
            error make {
                msg: $"Unknown action: ($action)"
            }
        }
    }
}

# List all available tools based on safety mode
def list_tools [] {
    let mode = get-safety-mode
    let all_schemas = get-all-schemas
    
    # Filter schemas based on safety mode
    let filtered_schemas = match $mode {
        "readonly" => {
            $all_schemas | where {|schema| 
                $schema.name in (readonly-tools)
            }
        },
        "non-destructive" => {
            $all_schemas | where {|schema| 
                $schema.name not-in (destructive-tools)
            }
        },
        "full" => {
            $all_schemas
        },
        _ => {
            $all_schemas
        }
    }
    
    {
        tools: $filtered_schemas
    }
}

# Call a specific tool
def call_tool [
    tool_name: string
    params: record
] {
    # Check if tool is allowed in current safety mode
    if not (is-tool-allowed $tool_name) {
        return (permission-denied-error $tool_name)
    }
    
    # Route to appropriate tool implementation
    match $tool_name {
        # Resource operations
        "kubectl_get" => { kubectl-get $params }
        "kubectl_describe" => { kubectl-describe $params }
        
        # Operations
        "kubectl_logs" => { kubectl-logs $params }
        "kubectl_context" => { kubectl-context $params }
        "explain_resource" => { explain-resource $params }
        "list_api_resources" => { list-api-resources $params }
        "ping" => { ping $params }
        
        # Unknown tool
        _ => {
            format-tool-response {
                error: "UnknownTool"
                message: $"Unknown tool: ($tool_name)"
                availableTools: (list_tools | get tools | get name)
                isError: true
            } --error
        }
    }
}

# Initialize and validate environment on module load
def --env init [] {
    # Check kubectl is available
    if not (check-kubectl) {
        print "Warning: kubectl is not installed or not in PATH"
        print "Please install kubectl to use this MCP server"
    }
    
    # Display current configuration
    let mode = get-safety-mode
    let context = get-current-context
    let namespace = get-default-namespace
    
    print $"Kubernetes MCP Server initialized"
    print $"  Safety Mode: ($mode)"
    print $"  Context: ($context)"
    print $"  Namespace: ($namespace)"
    print $"  Available Tools: (list_tools | get tools | length)"
}

# Auto-initialize when module is loaded
# init
