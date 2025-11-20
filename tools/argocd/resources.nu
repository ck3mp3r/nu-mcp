# ArgoCD Resource Management using HTTP API

use utils.nu *
use ../_common/toon.nu *

# Get managed resources for an application
export def get-managed-resources [
  instance: record # ArgoCD instance
  name: string # Application name
  namespace?: string # Filter by namespace
  resource_name?: string # Filter by resource name
  kind?: string # Filter by kind
] {
  mut params = {}

  if ($namespace != null) {
    $params = ($params | insert namespace $namespace)
  }

  if ($resource_name != null) {
    $params = ($params | insert name $resource_name)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  let response = api-request "get" $"/api/v1/applications/($name)/managed-resources" $instance --params $params
  let items = $response.items? | default []
  $items | to toon
}

# Get logs for application workload
export def get-workload-logs [
  instance: record # ArgoCD instance
  name: string # Application name
  resource_namespace?: string # Resource namespace
  resource_name?: string # Resource name
  kind?: string # Resource kind
  container?: string # Container name
  tail_lines?: int # Number of lines to tail
] {
  mut params = {
    follow: "false"
  }

  if ($resource_namespace != null) {
    $params = ($params | insert namespace $resource_namespace)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($container != null) {
    $params = ($params | insert container $container)
  }

  if ($tail_lines != null) {
    $params = ($params | insert tailLines ($tail_lines | into string))
  }

  api-request "get" $"/api/v1/applications/($name)/logs" $instance --params $params | to json --indent 2
}

# Get events for specific resource
export def get-resource-events [
  instance: record # ArgoCD instance
  name: string # Application name
  resource_namespace?: string # Resource namespace
  resource_name?: string # Resource name
  resource_uid?: string # Resource UID
] {
  mut params = {}

  if ($resource_namespace != null) {
    $params = ($params | insert resourceNamespace $resource_namespace)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  if ($resource_uid != null) {
    $params = ($params | insert resourceUID $resource_uid)
  }

  api-request "get" $"/api/v1/applications/($name)/events" $instance --params $params | to json --indent 2
}

# Get resource manifests
export def get-resources [
  instance: record # ArgoCD instance
  name: string # Application name
  app_namespace: string # Application namespace
] {
  # Get resource tree first
  let tree_response = api-request "get" $"/api/v1/applications/($name)/resource-tree" $instance
  let nodes = $tree_response.nodes? | default []

  # Fetch manifest for each resource
  $nodes | each {|node|
    mut params = {
      appNamespace: $app_namespace
      namespace: ($node.namespace? | default "")
      resourceName: ($node.name? | default "")
      group: ($node.group? | default "")
      kind: ($node.kind? | default "")
      version: ($node.version? | default "")
    }

    let response = api-request "get" $"/api/v1/applications/($name)/resource" $instance --params $params
    $response.manifest? | default null
  } | to json --indent 2
}

# Get available actions for a resource
export def get-resource-actions [
  instance: record # ArgoCD instance
  name: string # Application name
  namespace?: string # Resource namespace
  kind?: string # Resource kind
  resource_name?: string # Resource name
] {
  mut params = {}

  if ($namespace != null) {
    $params = ($params | insert namespace $namespace)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  let response = api-request "get" $"/api/v1/applications/($name)/resource/actions" $instance --params $params
  let actions = $response.actions? | default []
  $actions | to toon
}

# Run a resource action
export def run-resource-action [
  instance: record # ArgoCD instance
  name: string # Application name
  action: string # Action name
  namespace?: string # Resource namespace
  kind?: string # Resource kind
  resource_name?: string # Resource name
] {
  mut params = {}
  let body = {action: $action}

  if ($namespace != null) {
    $params = ($params | insert namespace $namespace)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  api-request "post" $"/api/v1/applications/($name)/resource/actions" $instance --body $body --params $params | to json --indent 2
}
