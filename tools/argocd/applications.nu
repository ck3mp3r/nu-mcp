# ArgoCD Application Management using HTTP API

use utils.nu *
use ../_common/toon.nu *

# Summarize application to reduce token usage
# Extracts only essential fields from full application object
# Flattened for TOON compatibility
def summarize-application [
  app: record
] {
  {
    name: ($app | get metadata.name? | default "unknown")
    namespace: ($app | get metadata.namespace? | default "")
    project: ($app | get spec.project? | default "")
    repoURL: ($app | get spec.source.repoURL? | default "")
    path: ($app | get spec.source.path? | default "")
    targetRevision: ($app | get spec.source.targetRevision? | default "")
    destServer: ($app | get spec.destination.server? | default "")
    destNamespace: ($app | get spec.destination.namespace? | default "")
    automated: (if ($app | get spec.syncPolicy.automated? | default null) != null { "true" } else { "false" })
    healthStatus: ($app | get status.health.status? | default "Unknown")
    syncStatus: ($app | get status.sync.status? | default "Unknown")
    syncRevision: ($app | get status.sync.revision? | default "")
    createdAt: ($app | get metadata.creationTimestamp? | default "")
  }
}

# List all applications
export def list-applications [
  instance: record # ArgoCD instance
  search?: string # Optional search filter (label selector)
  limit?: int # Optional limit
  summarize?: bool # Summarize results to reduce token usage (default: true)
] {
  mut params = {}

  if ($search != null) {
    $params = ($params | insert selector $search)
  }

  let response = api-request "get" "/api/v1/applications" $instance --params $params
  let all_items = $response.items? | default []

  # Apply limit if requested
  let limited_items = if $limit != null {
    $all_items | first $limit
  } else {
    $all_items
  }

  # Apply summarization if requested (default: true)
  let should_summarize = if ($summarize == null) { true } else { $summarize }
  let items = if $should_summarize {
    $limited_items | each {|app| summarize-application $app }
  } else {
    $limited_items
  }

  # Always use TOON format for lists
  $items | to toon
}

# Get application details
export def get-application [
  instance: record # ArgoCD instance
  name: string # Application name
  app_namespace?: string # Application namespace
] {
  mut params = {}

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  api-request "get" $"/api/v1/applications/($name)" $instance --params $params | to json --indent 2
}

# Get application resource tree
export def get-application-resource-tree [
  instance: record # ArgoCD instance
  name: string # Application name
] {
  api-request "get" $"/api/v1/applications/($name)/resource-tree" $instance | to json --indent 2
}

# Get application events
export def get-application-events [
  instance: record # ArgoCD instance
  name: string # Application name
] {
  api-request "get" $"/api/v1/applications/($name)/events" $instance | to json --indent 2
}

# Create a new application
export def create-application [
  instance: record # ArgoCD instance
  application: record # Application specification
] {
  api-request "post" "/api/v1/applications" $instance --body $application | to json --indent 2
}

# Update an existing application
export def update-application [
  instance: record # ArgoCD instance
  name: string # Application name
  application: record # Updated application specification
] {
  api-request "put" $"/api/v1/applications/($name)" $instance --body $application | to json --indent 2
}

# Delete an application
export def delete-application [
  instance: record # ArgoCD instance
  name: string # Application name
  app_namespace?: string # Application namespace
  cascade?: bool # Delete with cascade
  propagation_policy?: string # Propagation policy
] {
  mut params = {}

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  if ($cascade != null) {
    $params = ($params | insert cascade ($cascade | into string))
  }

  if ($propagation_policy != null) {
    $params = ($params | insert propagationPolicy $propagation_policy)
  }

  api-request "delete" $"/api/v1/applications/($name)" $instance --params $params | to json --indent 2
}

# Sync an application
export def sync-application [
  instance: record # ArgoCD instance
  name: string # Application name
  app_namespace?: string # Application namespace
  dry_run?: bool # Perform dry run
  prune?: bool # Prune resources
  revision?: string # Git revision to sync to
  sync_options?: list<string> # Sync options
] {
  mut sync_request = {}

  if ($dry_run != null and $dry_run) {
    $sync_request = ($sync_request | insert dryRun true)
  }

  if ($prune != null and $prune) {
    $sync_request = ($sync_request | insert prune true)
  }

  if ($revision != null) {
    $sync_request = ($sync_request | insert revision $revision)
  }

  if ($sync_options != null and ($sync_options | length) > 0) {
    $sync_request = ($sync_request | insert syncOptions $sync_options)
  }

  mut params = {}
  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  api-request "post" $"/api/v1/applications/($name)/sync" $instance --body $sync_request --params $params | to json --indent 2
}
