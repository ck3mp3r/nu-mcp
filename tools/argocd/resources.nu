# ArgoCD Resource Management using HTTP API

use utils.nu *

# Get application resource tree
export def get_resource_tree [
  name: string # Application name
] {
  api-request "get" $"/api/v1/applications/($name)/resource-tree"
}

# Get managed resources
export def get_managed_resources [
  name: string # Application name
  namespace?: string # Filter by namespace
  resource_name?: string # Filter by resource name
  version?: string # Filter by version
  group?: string # Filter by group
  kind?: string # Filter by kind
  app_namespace?: string # Application namespace
  project?: string # Filter by project
] {
  mut params = {}

  if ($namespace != null) {
    $params = ($params | insert namespace $namespace)
  }

  if ($resource_name != null) {
    $params = ($params | insert name $resource_name)
  }

  if ($version != null) {
    $params = ($params | insert version $version)
  }

  if ($group != null) {
    $params = ($params | insert group $group)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  if ($project != null) {
    $params = ($params | insert project $project)
  }

  let response = (api-request "get" $"/api/v1/applications/($name)/managed-resources" --params $params)
  {items: ($response.items? | default [])}
}

# Get logs for application or specific workload
export def get_logs [
  name: string # Application name
  app_namespace?: string # Application namespace
  resource_namespace?: string # Resource namespace
  resource_name?: string # Resource name
  group?: string # Resource group
  kind?: string # Resource kind
  version?: string # Resource version
  container?: string # Container name
  tail_lines?: int # Number of lines to tail
] {
  mut params = {}

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  if ($resource_namespace != null) {
    $params = ($params | insert namespace $resource_namespace)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  if ($group != null) {
    $params = ($params | insert group $group)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($version != null) {
    $params = ($params | insert version $version)
  }

  if ($container != null) {
    $params = ($params | insert container $container)
  }

  if ($tail_lines != null) {
    $params = ($params | insert tailLines ($tail_lines | into string))
  }

  $params = ($params | insert follow "false")

  api-request "get" $"/api/v1/applications/($name)/logs" --params $params
}

# Get events for an application
export def get_application_events [
  name: string # Application name
] {
  api-request "get" $"/api/v1/applications/($name)/events"
}

# Get events for specific resource
export def get_events [
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

  api-request "get" $"/api/v1/applications/($name)/events" --params $params
}

# Get resource manifests
export def get_resources [
  name: string # Application name
  app_namespace: string # Application namespace
  resource_refs?: list # List of resource references (optional, fetches all if not provided)
] {
  # If no resource refs provided, get all from resource tree
  let refs = if ($resource_refs == null or ($resource_refs | is-empty)) {
    let tree = (get_resource_tree $name)
    $tree.nodes? | default [] | each {|node|
      {
        uid: ($node.uid? | default "")
        version: ($node.version? | default "")
        group: ($node.group? | default "")
        kind: ($node.kind? | default "")
        name: ($node.name? | default "")
        namespace: ($node.namespace? | default "")
      }
    }
  } else {
    $resource_refs
  }

  # Fetch manifest for each resource
  $refs | each {|ref|
    mut params = {
      appNamespace: $app_namespace
      namespace: $ref.namespace
      resourceName: $ref.name
      group: $ref.group
      kind: $ref.kind
      version: $ref.version
    }

    let response = (api-request "get" $"/api/v1/applications/($name)/resource" --params $params)
    $response.manifest? | default null
  }
}

# Get available actions for a resource
export def get_resource_actions [
  name: string # Application name
  app_namespace?: string # Application namespace
  namespace?: string # Resource namespace
  kind?: string # Resource kind
  resource_name?: string # Resource name
] {
  mut params = {}

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  if ($namespace != null) {
    $params = ($params | insert namespace $namespace)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  let response = (api-request "get" $"/api/v1/applications/($name)/resource/actions" --params $params)
  {actions: ($response.actions? | default [])}
}

# Run a resource action
export def run_resource_action [
  name: string # Application name
  action: string # Action name
  app_namespace?: string # Application namespace
  namespace?: string # Resource namespace
  kind?: string # Resource kind
  resource_name?: string # Resource name
] {
  mut params = {}
  mut body = {action: $action}

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  if ($namespace != null) {
    $params = ($params | insert namespace $namespace)
  }

  if ($kind != null) {
    $params = ($params | insert kind $kind)
  }

  if ($resource_name != null) {
    $params = ($params | insert resourceName $resource_name)
  }

  api-request "post" $"/api/v1/applications/($name)/resource/actions" --body $body --params $params
}

# Get application manifests
export def get_manifests [
  name: string # Application name
  revision?: string # Git revision
] {
  mut params = {}

  if ($revision != null) {
    $params = ($params | insert revision $revision)
  }

  api-request "get" $"/api/v1/applications/($name)/manifests" --params $params
}
