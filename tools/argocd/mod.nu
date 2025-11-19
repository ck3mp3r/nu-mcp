# ArgoCD tool for nu-mcp - CLI-based authentication
# Uses argocd CLI for session management and auto-discovery

# Import helper modules
use cluster.nu
use applications.nu *
use resources.nu *
use formatters.nu *

# Check if read-only mode is enabled (default: true)
def is-read-only [] {
  let read_only = $env.MCP_READ_ONLY? | default "true"
  $read_only == "true"
}

# Default main command
def main [] {
  help main
}

# List discovered ArgoCD instances
export def "main list-instances" [] {
  cluster cache | to json
}

# List available MCP tools
def "main list-tools" [] {
  let read_only = is-read-only
  let all_tools = get-tool-definitions

  # Filter tools based on read-only mode
  let tools = if $read_only {
    $all_tools | where {|tool| is-tool-allowed $tool.name $read_only}
  } else {
    $all_tools
  }

  $tools | to json
}

# Call a specific tool with arguments
def "main call-tool" [
  tool_name: string
  args: any = {}
] {
  let read_only = is-read-only

  # Check if tool is allowed in current mode
  if not (is-tool-allowed $tool_name $read_only) {
    error make {
      msg: $"Tool '($tool_name)' is not available in read-only mode. Set MCP_READ_ONLY=false to enable write operations."
    }
  }

  let parsed = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  # Resolve ArgoCD instance via discovery
  let instance = cluster resolve $parsed

  # Route to tool (note: tool names are snake_case, functions are kebab-case)
  match $tool_name {
    "list_applications" => {
      let search = if "search" in $parsed { $parsed.search } else { null }
      let limit = if "limit" in $parsed { $parsed.limit } else { null }
      list-applications $instance $search $limit
    }
    "get_application" => {
      let app_namespace = if "appNamespace" in $parsed { $parsed.appNamespace } else { null }
      get-application $instance $parsed.applicationName $app_namespace
    }
    "get_application_resource_tree" => {
      get-application-resource-tree $instance $parsed.applicationName
    }
    "get_application_managed_resources" => {
      let namespace = if "namespace" in $parsed { $parsed.namespace } else { null }
      let resource_name = if "name" in $parsed { $parsed.name } else { null }
      let kind = if "kind" in $parsed { $parsed.kind } else { null }
      get-managed-resources $instance $parsed.applicationName $namespace $resource_name $kind
    }
    "get_application_workload_logs" => {
      let namespace = if "namespace" in $parsed { $parsed.namespace } else { null }
      let resource_name = if "resourceName" in $parsed { $parsed.resourceName } else { null }
      let kind = if "kind" in $parsed { $parsed.kind } else { null }
      let container = if "container" in $parsed { $parsed.container } else { null }
      let tail_lines = if "tailLines" in $parsed { $parsed.tailLines } else { null }
      get-workload-logs $instance $parsed.applicationName $namespace $resource_name $kind $container $tail_lines
    }
    "get_application_events" => {
      get-application-events $instance $parsed.applicationName
    }
    "get_resource_events" => {
      let resource_namespace = if "resourceNamespace" in $parsed { $parsed.resourceNamespace } else { null }
      let resource_name = if "resourceName" in $parsed { $parsed.resourceName } else { null }
      let resource_uid = if "resourceUID" in $parsed { $parsed.resourceUID } else { null }
      get-resource-events $instance $parsed.applicationName $resource_namespace $resource_name $resource_uid
    }
    "get_resources" => {
      get-resources $instance $parsed.applicationName $parsed.applicationNamespace
    }
    "get_resource_actions" => {
      let namespace = if "namespace" in $parsed { $parsed.namespace } else { null }
      let kind = if "kind" in $parsed { $parsed.kind } else { null }
      let resource_name = if "resourceName" in $parsed { $parsed.resourceName } else { null }
      get-resource-actions $instance $parsed.applicationName $namespace $kind $resource_name
    }
    "create_application" => {
      create-application $instance $parsed.application
    }
    "update_application" => {
      update-application $instance $parsed.applicationName $parsed.application
    }
    "delete_application" => {
      let app_namespace = if "appNamespace" in $parsed { $parsed.appNamespace } else { null }
      let cascade = if "cascade" in $parsed { $parsed.cascade } else { null }
      let policy = if "propagationPolicy" in $parsed { $parsed.propagationPolicy } else { null }
      delete-application $instance $parsed.applicationName $app_namespace $cascade $policy
    }
    "sync_application" => {
      let app_namespace = if "appNamespace" in $parsed { $parsed.appNamespace } else { null }
      let dry_run = if "dryRun" in $parsed { $parsed.dryRun } else { null }
      let prune = if "prune" in $parsed { $parsed.prune } else { null }
      let revision = if "revision" in $parsed { $parsed.revision } else { null }
      let sync_options = if "syncOptions" in $parsed { $parsed.syncOptions } else { null }
      sync-application $instance $parsed.applicationName $app_namespace $dry_run $prune $revision $sync_options
    }
    "run_resource_action" => {
      let namespace = if "namespace" in $parsed { $parsed.namespace } else { null }
      let kind = if "kind" in $parsed { $parsed.kind } else { null }
      let resource_name = if "resourceName" in $parsed { $parsed.resourceName } else { null }
      run-resource-action $instance $parsed.applicationName $parsed.action $namespace $kind $resource_name
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
