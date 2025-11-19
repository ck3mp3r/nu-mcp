# ArgoCD Cluster Discovery
# Discovers ArgoCD instances and credentials from Kubernetes

# Find all ArgoCD instances in the cluster
export def find [] {
  try {
    let namespaces = (
      kubectl get ns -l app.kubernetes.io/part-of=argocd -ojsonpath= '{.items[*].metadata.name}'
      | str trim
    )

    if ($namespaces | is-empty) {
      return []
    }

    $namespaces
    | split row ' '
    | each {|ns| parse $ns }
    | compact
  } catch {
    []
  }
}

# Parse single ArgoCD instance
export def parse [ns: string] {
  try {
    {
      namespace: $ns
      server: (get-server $ns)
      creds: (get-creds $ns)
    }
  } catch {
    null
  }
}

# Get server URL for ArgoCD instance
def get-server [ns: string] {
  try {
    let svc = kubectl get svc argocd-server -n $ns -o json | from json

    # Try LoadBalancer IP
    let lb_ip = $svc.status?.loadBalancer?.ingress?.0?.ip?
    if $lb_ip != null {
      return $"https://($lb_ip)"
    }

    # Try LoadBalancer hostname
    let lb_host = $svc.status?.loadBalancer?.ingress?.0?.hostname?
    if $lb_host != null {
      return $"https://($lb_host)"
    }

    # Check for annotations with external URL
    let external_url = $svc.metadata?.annotations?."argocd.argoproj.io/external-url"?
    if $external_url != null {
      return $external_url
    }

    # Fallback to in-cluster service name (for port-forward scenarios)
    return $"https://argocd-server.($ns).svc.cluster.local"
  } catch {
    error make {msg: $"Failed to get server URL for namespace ($ns)"}
  }
}

# Get credentials for ArgoCD instance
def get-creds [ns: string] {
  # Try initial admin secret
  let initial_secret = try-secret $ns "argocd-initial-admin-secret" {|data|
    {
      username: "admin"
      password: ($data.password? | default "")
    }
  }

  if $initial_secret != null {
    return $initial_secret
  }

  # Try MCP credentials secret
  let mcp_secret = try-secret $ns "argocd-mcp-credentials" {|data|
    {
      username: ($data.username? | default "admin")
      password: ($data.password? | default "")
    }
  }

  if $mcp_secret != null {
    return $mcp_secret
  }

  # No credentials found
  error make {msg: $"No credentials found for ArgoCD in namespace ($ns)"}
}

# Try to get secret with transform
def try-secret [
  ns: string
  name: string
  transform: closure
] {
  try {
    let secret_data = (
      kubectl get secret $name -n $ns -ojsonpath= '{.data}'
      | from json
    )

    # Decode base64 values
    let decoded = $secret_data
    | items {|k v| {$k: ($v | decode base64 | decode utf-8 | str trim)} }
    | into record

    # Apply transform
    do $transform $decoded
  } catch {
    null
  }
}

# Resolve instance from args or discover
export def resolve [args: record] {
  # Check for explicit namespace parameter
  if "namespace" in $args {
    let instance = parse $args.namespace
    if $instance == null {
      error make {msg: $"ArgoCD instance not found in namespace ($args.namespace)"}
    }
    return $instance
  }

  # Check for explicit server parameter
  if "server" in $args {
    let all = cache
    let found = $all | where server == $args.server
    if ($found | is-empty) {
      error make {msg: $"ArgoCD instance not found with server ($args.server)"}
    }
    return ($found | first)
  }

  # Try current kubectl context namespace
  let current_ns = try {
    kubectl config view --minify -ojsonpath= '{.contexts[0].context.namespace}' | str trim
  } catch { "" }

  if ($current_ns | str starts-with "argocd") {
    let instance = parse $current_ns
    if $instance != null {
      return $instance
    }
  }

  # Use first discovered instance
  let instances = cache
  if ($instances | is-empty) {
    error make {msg: "No ArgoCD instances found in cluster"}
  }

  $instances | first
}

# Cache management
export def cache [] {
  const TTL = 5min
  let cache_dir = $"($env.HOME)/.cache/nu-mcp"
  let cache_file = $"($cache_dir)/argocd.json"

  if (cache-valid $cache_file $TTL) {
    try {
      open $cache_file | from json
    } catch {
      # Cache corrupted, re-discover
      refresh-cache $cache_dir $cache_file
    }
  } else {
    refresh-cache $cache_dir $cache_file
  }
}

# Refresh cache
def refresh-cache [cache_dir: string cache_file: string] {
  let instances = find

  # Create cache directory if it doesn't exist
  if not ($cache_dir | path exists) {
    mkdir $cache_dir
  }

  # Save to cache
  $instances | to json | save -f $cache_file
  $instances
}

# Check if cache is valid
def cache-valid [file: string ttl: duration] {
  if not ($file | path exists) {
    return false
  }

  let file_info = ls $file | first
  let age = (date now) - $file_info.modified
  $age < $ttl
}
