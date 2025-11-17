# Kubernetes MCP Server
# Model Context Protocol server for Kubernetes cluster management

use utils.nu *
use formatters.nu *
use resources.nu *
use operations.nu *
use helm.nu *

# Default main command - show help
export def main [] {
  help main
}

# List available MCP tools
export def "main list-tools" [] {
  list_tools
}

# Call a specific MCP tool
export def "main call-tool" [
  tool_name: string
  args: any = "{}"
] {
  # Handle both string (from Rust via -c) and record (from direct script invocation)
  let params = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }
  call_tool $tool_name $params
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
    }
    "non-destructive" => {
      $all_schemas | where {|schema|
        $schema.name not-in (destructive-tools)
      }
    }
    "destructive" => {
      $all_schemas
    }
    _ => {
      $all_schemas | where {|schema|
        $schema.name in (readonly-tools)
      }
    }
  }

  $filtered_schemas | to json
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
    # Phase 1A: Read-only resource operations
    "kube-get" => { kubectl-get $params }
    "kube-describe" => { kubectl-describe $params }

    # Phase 1A: Read-only operations
    "kube-logs" => { kubectl-logs $params }
    "kube-context" => { kubectl-context $params }
    "kube-explain" => { explain-resource $params }
    "kube-api-resources" => { list-api-resources $params }
    "kube-ping" => { ping $params }

    # Phase 1B: Write resource operations
    "kube-apply" => { kubectl-apply $params }
    "kube-create" => { kubectl-create $params }
    "kube-patch" => { kubectl-patch $params }

    # Phase 1B: Write operations
    "kube-scale" => { kubectl-scale $params }
    "kube-rollout" => { kubectl-rollout $params }
    "kube-exec" => { exec-in-pod $params }
    "kube-port-forward" => { port-forward $params }
    "kube-port-forward-stop" => { kube-port-forward-stop $params }

    # Phase 1B: Helm operations
    "helm-install" => { helm-install $params }
    "helm-upgrade" => { helm-upgrade $params }

    # Phase 2: Destructive operations
    "kube-delete" => { kubectl-delete $params }
    "helm-uninstall" => { helm-uninstall $params }
    "kube-node" => { node-management $params }
    "kube-cleanup" => { cleanup $params }

    # Unknown tool
    _ => {
      format-tool-response {
        error: "UnknownTool"
        message: $"Unknown tool: ($tool_name)"
        availableTools: (list_tools | get tools | get name)
        isError: true
      } --error true
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
