# Kubernetes MCP Tool - Utility Functions
# kubectl wrapper, safety checks, and helper functions

# Check if kubectl is installed and accessible
export def check-kubectl [] {
  try {
    kubectl version --client --output json | from json
    true
  } catch {
    false
  }
}

# Get kubectl version info
export def get-kubectl-version [] {
  try {
    kubectl version --client --output json | from json | get clientVersion
  } catch {
    {
      error: "kubectl not found or not accessible"
      message: "Please install kubectl and ensure it's in your PATH"
    }
  }
}

# Get current kubeconfig context
export def get-current-context [] {
  try {
    kubectl config current-context | str trim
  } catch {
    ""
  }
}

# List all available contexts
export def list-contexts [] {
  try {
    kubectl config get-contexts --output json
    | from json
    | get contexts
    | select name context.cluster context.user context.namespace
    | rename name cluster user namespace
  } catch {
    []
  }
}

# Validate resource type against kubectl api-resources
export def validate-resource-type [type: string] {
  try {
    let resources = (kubectl api-resources --output name | lines)
    ($type in $resources) or ($type | str downcase in $resources)
  } catch {
    false
  }
}

# Get safety mode from environment variables
export def get-safety-mode [] {
  let mode = ($env.MCP_K8S_MODE? | default "readonly")

  # Validate mode and default to readonly for invalid values
  if $mode in ["readonly" "non-destructive" "destructive"] {
    $mode
  } else {
    print -e $"Warning: Invalid MCP_K8S_MODE='($mode)'. Valid values: readonly, non-destructive, destructive. Defaulting to readonly."
    "readonly"
  }
}

# Define read-only tools (7 tools)
export def readonly-tools [] {
  [
    "kubectl_get"
    "kubectl_describe"
    "kubectl_logs"
    "kubectl_context"
    "explain_resource"
    "list_api_resources"
    "ping"
  ]
}

# Define destructive tools (5 tools)
export def destructive-tools [] {
  [
    "kubectl_delete"
    "helm_uninstall"
    "cleanup"
    "node_management"
  ]
}

# Check if a tool is allowed in current safety mode
export def is-tool-allowed [tool_name: string] {
  let mode = (get-safety-mode)

  match $mode {
    "readonly" => {
      $tool_name in (readonly-tools)
    }
    "non-destructive" => {
      $tool_name not-in (destructive-tools)
    }
    "destructive" => {
      true
    }
    _ => {
      false
    }
  }
}

# Generate permission denied error
export def permission-denied-error [tool_name: string] {
  let mode = (get-safety-mode)

  let message = match $mode {
    "readonly" => $"Tool '($tool_name)' requires write access. Set MCP_K8S_MODE=non-destructive to enable."
    "non-destructive" => $"Tool '($tool_name)' is a destructive operation. Set MCP_K8S_MODE=destructive to enable."
    _ => $"Tool '($tool_name)' is not allowed in current mode."
  }

  {
    error: "PermissionDenied"
    message: $message
    tool: $tool_name
    mode: $mode
    isError: true
  }
}

# Main kubectl command wrapper
export def run-kubectl [
  args: list<string>
  --stdin: string = ""
  --namespace: string = ""
  --context: string = ""
  --output: string = "json"
  --all-namespaces = false
] {
  # Build base command
  mut cmd_args = ["kubectl"]

  # Add context if specified (global flag, goes before subcommand)
  let ctx = if $context != "" {
    $context
  } else {
    $env.KUBE_CONTEXT? | default ""
  }

  if $ctx != "" {
    $cmd_args = ($cmd_args | append ["--context" $ctx])
  }

  # Add the actual kubectl command arguments (e.g., "get", "pods")
  $cmd_args = ($cmd_args | append $args)

  # Add namespace if specified (command-specific flag, after subcommand)
  if not $all_namespaces and $namespace != "" {
    $cmd_args = ($cmd_args | append ["--namespace" $namespace])
  } else if not $all_namespaces {
    let default_ns = $env.KUBE_NAMESPACE? | default "default"
    if $default_ns != "" {
      $cmd_args = ($cmd_args | append ["--namespace" $default_ns])
    }
  }

  # Add all-namespaces flag if specified
  if $all_namespaces {
    $cmd_args = ($cmd_args | append ["--all-namespaces"])
  }

  # Add output format if applicable
  if $output in ["json" "yaml"] and not ("--output" in $args or "-o" in $args) {
    $cmd_args = ($cmd_args | append ["--output" $output])
  }

  # Capture command string for error reporting
  let cmd_str = ($cmd_args | str join " ")

  # Execute kubectl command
  try {
    let kubectl_args = ($cmd_args | skip 1) # Skip "kubectl" string
    let result = if $stdin != "" {
      # Use stdin if provided
      $stdin | ^kubectl ...$kubectl_args
    } else {
      ^kubectl ...$kubectl_args
    }

    # Parse output based on format
    if $output == "json" {
      try {
        $result | from json
      } catch {
        # If JSON parsing fails, return as text
        $result | str trim
      }
    } else if $output == "yaml" {
      try {
        $result | from yaml
      } catch {
        $result | str trim
      }
    } else {
      # Return as text for other formats
      $result | str trim
    }
  } catch {
    # Return error information
    let error_msg = $in | str trim
    {
      error: "KubectlCommandFailed"
      message: $error_msg
      command: $cmd_str
      isError: true
    }
  }
}

# Parse kubectl output and handle errors
export def parse-kubectl-output [
  output: string
  format: string = "json"
] {
  if ($output | str trim | str starts-with "Error") {
    {
      error: "KubectlError"
      message: ($output | str trim)
      isError: true
    }
  } else {
    if $format == "json" {
      try {
        $output | from json
      } catch {
        $output | str trim
      }
    } else if $format == "yaml" {
      try {
        $output | from yaml
      } catch {
        $output | str trim
      }
    } else {
      $output | str trim
    }
  }
}

# Get default namespace from environment or kubeconfig
export def get-default-namespace [] {
  # First check env var
  let env_ns = $env.KUBE_NAMESPACE? | default ""
  if $env_ns != "" {
    return $env_ns
  }

  # Try to get from current context
  try {
    let ctx_ns = (
      kubectl config view --minify --output json
      | from json
      | get contexts.0.context.namespace?
    )

    if $ctx_ns != null {
      return $ctx_ns
    }
  } catch { }

  # Default to "default"
  "default"
}

# Mask secrets in kubectl output
export def mask-secrets [data: any] {
  # Check if this is secret data
  if ($data | describe | str contains "record") {
    if ($data | get kind? | default "" | str downcase) == "secret" {
      # Mask the data field
      $data | upsert data {
        $data | get data | columns | reduce -f {} {|key acc|
          $acc | insert $key "***MASKED***"
        }
      }
    } else {
      $data
    }
  } else if ($data | describe | str contains "list") {
    # Handle lists
    $data | each {|item| mask-secrets $item }
  } else {
    $data
  }
}

# Format MCP tool response
export def format-tool-response [
  content: any
  --error = false
] {
  if $error {
    {
      content: [
        {
          type: "text"
          text: ($content | to json --indent 2)
        }
      ]
      isError: true
    }
  } else {
    {
      content: [
        {
          type: "text"
          text: ($content | to json --indent 2)
        }
      ]
    }
  }
}

# Validate kubectl is available and cluster is accessible
export def validate-kubectl-access [] {
  # Check kubectl exists
  if not (check-kubectl) {
    return {
      error: "KubectlNotFound"
      message: "kubectl is not installed or not in PATH. Please install kubectl."
      isError: true
    }
  }

  # Check cluster connectivity
  try {
    kubectl cluster-info | complete
    {
      status: "ok"
      version: (get-kubectl-version)
      context: (get-current-context)
      namespace: (get-default-namespace)
    }
  } catch {
    {
      error: "ClusterUnreachable"
      message: "Cannot connect to Kubernetes cluster. Check your kubeconfig and cluster status."
      isError: true
    }
  }
}

# Check if a resource type is non-namespaced (cluster-scoped)
export def is-non-namespaced-resource [
  resource_type: string
] {
  let non_namespaced = [
    "nodes"
    "node"
    "no"
    "namespaces"
    "namespace"
    "ns"
    "persistentvolumes"
    "pv"
    "storageclasses"
    "sc"
    "clusterroles"
    "clusterrolebindings"
    "customresourcedefinitions"
    "crd"
    "crds"
  ]

  $resource_type | str downcase | $in in $non_namespaced
}
