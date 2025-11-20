# ArgoCD Cluster Discovery
# Discovers ArgoCD instances and credentials from Kubernetes

# Find all ArgoCD instances in the cluster
export def find [] {
  # Phase 1: Try to find namespaces with the standard ArgoCD label
  let labeled = try {
    kubectl get ns -l app.kubernetes.io/part-of=argocd -ojsonpath='{.items[*].metadata.name}'
    | str trim
    | split row ' '
    | where {|ns| not ($ns | is-empty) }
  } catch {
    []
  }

  if not ($labeled | is-empty) {
    return ($labeled | each {|ns| parse $ns } | compact)
  }

  # Phase 2: Fallback to checking common ArgoCD namespace names
  ["argocd" "argocd-system" "argo-cd"]
  | each {|ns|
    try {
      kubectl get svc argocd-server -n $ns -o name | complete
      | if $in.exit_code == 0 { parse $ns } else { null }
    } catch {
      null
    }
  }
  | compact
}

# Parse single ArgoCD instance
export def parse [ns: string] {
  try {
    let server = get-server $ns

    # If no accessible server URL, mark as needing port-forward
    if $server == null {
      {
        namespace: $ns
        server: null
        creds: (get-creds $ns)
        needs_port_forward: true
      }
    } else {
      {
        namespace: $ns
        server: $server
        creds: (get-creds $ns)
        needs_port_forward: false
      }
    }
  } catch {
    null
  }
}

# Get server URL for ArgoCD instance
def get-server [ns: string] {
  try {
    let svc = kubectl get svc argocd-server -n $ns -o json | from json

    # Check for external URL annotation
    let external_url = $svc.metadata?.annotations?."argocd.argoproj.io/external-url"?
    if $external_url != null {
      return $external_url
    }

    # Check for LoadBalancer IP
    let lb_ip = $svc.status?.loadBalancer?.ingress?.0?.ip?
    if $lb_ip != null {
      return $"https://($lb_ip)"
    }

    # Check for LoadBalancer hostname  
    let lb_host = $svc.status?.loadBalancer?.ingress?.0?.hostname?
    if $lb_host != null {
      return $"https://($lb_host)"
    }

    # No accessible URL - return null, caller will error with port-forward instructions
    null
  } catch {
    error make {msg: $"Failed to get ArgoCD service in namespace ($ns)"}
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
      kubectl get secret $name -n $ns -ojsonpath='{.data}'
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
  # Explicit server + namespace: use provided server with discovered creds
  if ("server" in $args) and ("namespace" in $args) {
    let creds = get-creds $args.namespace
    if $creds == null {
      error make {msg: $"No credentials found in namespace ($args.namespace)"}
    }
    return {
      server: $args.server
      namespace: $args.namespace
      creds: $creds
    }
  }

  # Explicit server only: user has already logged in via argocd CLI, skip all discovery
  if "server" in $args {
    return {
      server: $args.server
      namespace: null
      creds: null
    }
  }

  # Check for explicit namespace parameter (auto-discover server and creds from k8s)
  if "namespace" in $args {
    let instance = parse $args.namespace
    if $instance == null {
      error make {msg: $"ArgoCD instance not found in namespace ($args.namespace)"}
    }

    # Check if port-forward is needed and provide instructions
    if $instance.needs_port_forward? == true {
      error make {
        msg: $"ArgoCD found in namespace '($instance.namespace)' but has no accessible URL.

ACTION REQUIRED: Use k8s tool to set up port-forward:
  kube_port_forward with: resourceType='service', resourceName='argocd-server', namespace='($instance.namespace)', localPort=8080, targetPort=443

Then retry ArgoCD with: server='https://localhost:8080', namespace='($instance.namespace)'"
      }
    }

    return $instance
  }

  # Full auto-discovery: try current kubectl context namespace
  let current_ns = try {
    kubectl config view --minify -ojsonpath='{.contexts[0].context.namespace}' | str trim
  } catch { "" }

  if ($current_ns | str starts-with "argocd") {
    let instance = parse $current_ns
    if $instance != null {
      # Check if port-forward is needed
      if $instance.needs_port_forward? == true {
        error make {
          msg: $"ArgoCD found in namespace '($instance.namespace)' but has no accessible URL.

ACTION REQUIRED: Use k8s tool to set up port-forward:
  kube_port_forward with: resourceType='service', resourceName='argocd-server', namespace='($instance.namespace)', localPort=8080, targetPort=443

Then retry ArgoCD with: server='https://localhost:8080', namespace='($instance.namespace)'"
        }
      }
      return $instance
    }
  }

  # Use first discovered instance
  let instances = cache
  if ($instances | is-empty) {
    error make {msg: "No ArgoCD instances found in cluster"}
  }

  let first_instance = $instances | first

  # Check if port-forward is needed
  if $first_instance.needs_port_forward? == true {
    error make {
      msg: $"ArgoCD found in namespace '($first_instance.namespace)' but has no accessible URL.

ACTION REQUIRED: Use k8s tool to set up port-forward:
  kube_port_forward with: resourceType='service', resourceName='argocd-server', namespace='($first_instance.namespace)', localPort=8080, targetPort=443

Then retry ArgoCD with: server='https://localhost:8080', namespace='($first_instance.namespace)'"
    }
  }

  $first_instance
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
