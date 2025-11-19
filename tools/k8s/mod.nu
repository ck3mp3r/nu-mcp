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
    "kube_get" => { kubectl-get $params }
    "kube_describe" => { kubectl-describe $params }

    "kube_logs" => { kubectl-logs $params }
    "kube_context" => { kubectl-context $params }
    "kube_explain" => { explain-resource $params }
    "kube_api_resources" => { list-api-resources $params }
    "kube_ping" => { ping $params }

    "kube_apply" => { kubectl-apply $params }
    "kube_create" => { kubectl-create $params }
    "kube_patch" => { kubectl-patch $params }

    "kube_scale" => { kubectl-scale $params }
    "kube_rollout" => { kubectl-rollout $params }
    "kube_exec" => { exec-in-pod $params }
    "kube_port_forward" => { port-forward $params }
    "kube_port_forward_stop" => { kube-port-forward-stop $params }

    "helm_install" => { helm-install $params }
    "helm_upgrade" => { helm-upgrade $params }

    "kube_delete" => { kubectl-delete $params }
    "helm_uninstall" => { helm-uninstall $params }
    "kube_node" => { node-management $params }
    "kube_cleanup" => { cleanup $params }

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
