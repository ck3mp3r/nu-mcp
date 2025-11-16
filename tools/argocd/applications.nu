# ArgoCD Application Management using HTTP API

use utils.nu *

# List all applications
export def list_applications [
  search?: string # Optional search filter (label selector)
  limit?: int # Optional limit
  offset?: int # Optional offset
] {
  mut params = {}

  if ($search != null) {
    $params = ($params | insert selector $search)
  }

  let response = (api-request "get" "/api/v1/applications" --params $params)
  let all_items = $response.items? | default []

  # Apply pagination if requested
  let items = if ($offset != null or $limit != null) {
    let start = ($offset | default 0)
    let end = if ($limit != null) { $start + $limit } else { ($all_items | length) }
    $all_items | range $start..<$end
  } else {
    $all_items
  }

  {
    items: $items
    metadata: {
      totalItems: ($all_items | length)
      returnedItems: ($items | length)
      hasMore: (($limit != null) and (($offset | default 0) + $limit < ($all_items | length)))
    }
  }
}

# Get application details
export def get_application [
  name: string # Application name
  app_namespace?: string # Application namespace
] {
  mut params = {}

  if ($app_namespace != null) {
    $params = ($params | insert appNamespace $app_namespace)
  }

  api-request "get" $"/api/v1/applications/($name)" --params $params
}

# Create a new application
export def create_application [
  application: record # Application specification
] {
  api-request "post" "/api/v1/applications" --body $application
}

# Update an existing application
export def update_application [
  name: string # Application name
  application: record # Updated application specification
] {
  api-request "put" $"/api/v1/applications/($name)" --body $application
}

# Delete an application
export def delete_application [
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

  api-request "delete" $"/api/v1/applications/($name)" --params $params
}

# Sync an application
export def sync_application [
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

  api-request "post" $"/api/v1/applications/($name)/sync" --body $sync_request --params $params
}
