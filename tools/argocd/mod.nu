# ArgoCD tool for nu-mcp - provides ArgoCD application and resource management
# Uses HTTP API for all operations

# Import helper modules
use utils.nu *
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

# List available MCP tools
def "main list-tools" [] {
  let read_only = (is-read-only)
  let all_tools = (get-tool-definitions)

  # Filter tools based on read-only mode
  let tools = if $read_only {
    $all_tools | where {|tool| is-tool-allowed $tool.name $read_only }
  } else {
    $all_tools
  }

  $tools | to json
}

# Call a specific tool with arguments
def "main call-tool" [
  tool_name: string # Name of the tool to call
  args: any = {} # JSON arguments for the tool
] {
  let read_only = (is-read-only)

  # Check if tool is allowed in current mode
  if not (is-tool-allowed $tool_name $read_only) {
    error make {
      msg: $"Tool '($tool_name)' is not available in read-only mode. Set MCP_READ_ONLY=false to enable write operations."
    }
  }

  let parsed_args = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  match $tool_name {
    "list_applications" => {
      let search = if "search" in $parsed_args { $parsed_args | get search } else { null }
      let limit = if "limit" in $parsed_args { $parsed_args | get limit } else { null }
      let offset = if "offset" in $parsed_args { $parsed_args | get offset } else { null }
      list_applications $search $limit $offset
    }
    "get_application" => {
      let name = $parsed_args | get applicationName
      let app_namespace = if "appNamespace" in $parsed_args { $parsed_args | get appNamespace } else { null }
      get_application $name $app_namespace
    }
    "create_application" => {
      let app = $parsed_args | get application
      create_application $app
    }
    "update_application" => {
      let name = $parsed_args | get applicationName
      let app = $parsed_args | get application
      update_application $name $app
    }
    "delete_application" => {
      let name = $parsed_args | get applicationName
      let app_namespace = if "appNamespace" in $parsed_args { $parsed_args | get appNamespace } else { null }
      let cascade = if "cascade" in $parsed_args { $parsed_args | get cascade } else { null }
      let policy = if "propagationPolicy" in $parsed_args { $parsed_args | get propagationPolicy } else { null }
      delete_application $name $app_namespace $cascade $policy
    }
    "sync_application" => {
      let name = $parsed_args | get applicationName
      let app_namespace = if "appNamespace" in $parsed_args { $parsed_args | get appNamespace } else { null }
      let dry_run = if "dryRun" in $parsed_args { $parsed_args | get dryRun } else { null }
      let prune = if "prune" in $parsed_args { $parsed_args | get prune } else { null }
      let revision = if "revision" in $parsed_args { $parsed_args | get revision } else { null }
      let sync_options = if "syncOptions" in $parsed_args { $parsed_args | get syncOptions } else { null }
      sync_application $name $app_namespace $dry_run $prune $revision $sync_options
    }
    "get_application_resource_tree" => {
      let name = $parsed_args | get applicationName
      get_resource_tree $name
    }
    "get_application_managed_resources" => {
      let name = $parsed_args | get applicationName
      let namespace = if "namespace" in $parsed_args { $parsed_args | get namespace } else { null }
      let resource_name = if "name" in $parsed_args { $parsed_args | get name } else { null }
      let version = if "version" in $parsed_args { $parsed_args | get version } else { null }
      let group = if "group" in $parsed_args { $parsed_args | get group } else { null }
      let kind = if "kind" in $parsed_args { $parsed_args | get kind } else { null }
      let app_namespace = if "appNamespace" in $parsed_args { $parsed_args | get appNamespace } else { null }
      let project = if "project" in $parsed_args { $parsed_args | get project } else { null }
      get_managed_resources $name $namespace $resource_name $version $group $kind $app_namespace $project
    }
    "get_application_workload_logs" => {
      let name = $parsed_args | get applicationName
      let app_namespace = if "applicationNamespace" in $parsed_args { $parsed_args | get applicationNamespace } else { null }
      let namespace = if "namespace" in $parsed_args { $parsed_args | get namespace } else { null }
      let resource_name = if "resourceName" in $parsed_args { $parsed_args | get resourceName } else { null }
      let group = if "group" in $parsed_args { $parsed_args | get group } else { null }
      let kind = if "kind" in $parsed_args { $parsed_args | get kind } else { null }
      let version = if "version" in $parsed_args { $parsed_args | get version } else { null }
      let container = if "container" in $parsed_args { $parsed_args | get container } else { null }
      let tail_lines = if "tailLines" in $parsed_args { $parsed_args | get tailLines } else { null }
      get_logs $name $app_namespace $namespace $resource_name $group $kind $version $container $tail_lines
    }
    "get_application_events" => {
      let name = $parsed_args | get applicationName
      get_application_events $name
    }
    "get_resource_events" => {
      let name = $parsed_args | get applicationName
      let app_namespace = $parsed_args | get applicationNamespace
      let resource_uid = $parsed_args | get resourceUID
      let resource_namespace = $parsed_args | get resourceNamespace
      let resource_name = $parsed_args | get resourceName
      get_events $name $resource_namespace $resource_name $resource_uid
    }
    "get_resources" => {
      let name = $parsed_args | get applicationName
      let app_namespace = $parsed_args | get applicationNamespace
      let resource_refs = if "resourceRefs" in $parsed_args { $parsed_args | get resourceRefs } else { null }
      get_resources $name $app_namespace $resource_refs
    }
    "get_resource_actions" => {
      let name = $parsed_args | get applicationName
      let app_namespace = if "applicationNamespace" in $parsed_args { $parsed_args | get applicationNamespace } else { null }
      let namespace = if "namespace" in $parsed_args { $parsed_args | get namespace } else { null }
      let kind = if "kind" in $parsed_args { $parsed_args | get kind } else { null }
      let resource_name = if "resourceName" in $parsed_args { $parsed_args | get resourceName } else { null }
      get_resource_actions $name $app_namespace $namespace $kind $resource_name
    }
    "run_resource_action" => {
      let name = $parsed_args | get applicationName
      let action = $parsed_args | get action
      let app_namespace = if "applicationNamespace" in $parsed_args { $parsed_args | get applicationNamespace } else { null }
      let namespace = if "namespace" in $parsed_args { $parsed_args | get namespace } else { null }
      let kind = if "kind" in $parsed_args { $parsed_args | get kind } else { null }
      let resource_name = if "resourceName" in $parsed_args { $parsed_args | get resourceName } else { null }
      run_resource_action $name $action $app_namespace $namespace $kind $resource_name
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
