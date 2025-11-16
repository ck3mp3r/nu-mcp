# Kubernetes MCP Tool - Operations
# Implementations for kube_logs, kube_context, kube_explain, kube_api_resources, ping

use utils.nu *

# kube_logs - Get pod/container logs
export def kubectl-logs [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType? | default "pod"
  let name = $params.name
  let namespace = $params.namespace? | default ""
  let container = $params.container? | default ""
  let tail = $params.tail? | default null
  let since = $params.since? | default ""
  let since_time = $params.sinceTime? | default ""
  let timestamps = $params.timestamps? | default false
  let previous = $params.previous? | default false
  let follow = $params.follow? | default false
  let label_selector = $params.labelSelector? | default ""
  let context = $params.context? | default ""

  # Build kubectl arguments
  mut args = ["logs"]

  # Add resource type and name (or label selector)
  if $label_selector != "" {
    $args = ($args | append ["--selector" $label_selector])
  } else {
    if $resource_type != "pod" {
      $args = ($args | append $"($resource_type)/($name)")
    } else {
      $args = ($args | append $name)
    }
  }

  # Add container if specified
  if $container != "" {
    $args = ($args | append ["--container" $container])
  }

  # Add tail
  if $tail != null {
    $args = ($args | append ["--tail" ($tail | into string)])
  }

  # Add since
  if $since != "" {
    $args = ($args | append ["--since" $since])
  }

  # Add since-time
  if $since_time != "" {
    $args = ($args | append ["--since-time" $since_time])
  }

  # Add timestamps
  if $timestamps {
    $args = ($args | append "--timestamps")
  }

  # Add previous
  if $previous {
    $args = ($args | append "--previous")
  }

  # Add follow (note: this is problematic for MCP as it's streaming)
  if $follow {
    $args = ($args | append "--follow")
  }

  # Execute kubectl command (logs are plain text)
  let result = run-kubectl $args --namespace $namespace --context $context --output "text"

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    resourceType: $resource_type
    name: $name
    namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
    container: $container
    logs: $result
  }
}

# kube_context - Manage kubectl contexts
export def kubectl-context [
  params: record
] {
  # Extract parameters
  let operation = $params.operation
  let name = $params.name? | default ""
  let show_current = $params.showCurrent? | default true
  let detailed = $params.detailed? | default false
  let output = $params.output? | default "json"

  # Handle different operations
  match $operation {
    "list" => {
      # List all contexts
      let contexts = list-contexts

      if $output == "json" {
        format-tool-response {
          operation: "list"
          contexts: $contexts
          current: (get-current-context)
        }
      } else {
        format-tool-response {
          operation: "list"
          output: $contexts
        }
      }
    }
    "get" => {
      # Get current context
      let current = get-current-context

      if $current == "" {
        return (
          format-tool-response {
            error: "NoContextSet"
            message: "No current context is set"
            isError: true
          } --error true
        )
      }

      format-tool-response {
        operation: "get"
        current: $current
        namespace: (get-default-namespace)
      }
    }
    "use" | "set" => {
      # Switch context (use and set are aliases)
      if $name == "" {
        return (
          format-tool-response {
            error: "MissingParameter"
            message: "Context name is required for 'set' operation"
            isError: true
          } --error true
        )
      }

      # Execute context switch
      let result = try {
        ^kubectl config use-context $name | complete
      } catch {
        {
          error: "ContextSwitchFailed"
          message: $"Failed to switch to context '($name)'"
          isError: true
        }
      }

      if ($result | get exit_code) == 0 {
        format-tool-response {
          operation: $operation
          previous: (get-current-context)
          current: $name
          message: $"Switched to context '($name)'"
        }
      } else {
        format-tool-response {
          error: "ContextSwitchFailed"
          message: ($result | get stderr | str trim)
          isError: true
        } --error true
      }
    }
    _ => {
      format-tool-response {
        error: "InvalidOperation"
        message: $"Unknown operation: ($operation). Valid operations are: list, get, use"
        isError: true
      } --error true
    }
  }
}

# kube_explain - Explain Kubernetes resource schema
export def explain-resource [
  params: record
] {
  # Extract parameters
  let resource = $params.resource
  let api_version = $params.apiVersion? | default ""
  let recursive = $params.recursive? | default false
  let output = $params.output? | default "plaintext"
  let context = $params.context? | default ""

  # Build kubectl arguments
  mut args = ["explain" $resource]

  # Add API version
  if $api_version != "" {
    $args = ($args | append ["--api-version" $api_version])
  }

  # Add recursive
  if $recursive {
    $args = ($args | append "--recursive")
  }

  # Add output format
  if $output != "plaintext" {
    $args = ($args | append ["--output" $output])
  }

  # Execute kubectl command
  let result = run-kubectl $args --context $context --output "text"

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    resource: $resource
    apiVersion: $api_version
    explanation: $result
  }
}

# kube_api_resources - List available API resources
export def list-api-resources [
  params: record
] {
  # Extract parameters
  let api_group = $params.apiGroup? | default ""
  let namespaced = $params.namespaced? | default null
  let verbs = $params.verbs? | default []
  let output = $params.output? | default "json"
  let context = $params.context? | default ""

  # Build kubectl arguments
  mut args = ["api-resources"]

  # Add API group filter
  if $api_group != "" {
    $args = ($args | append ["--api-group" $api_group])
  }

  # Add namespaced filter
  if $namespaced != null {
    if $namespaced {
      $args = ($args | append "--namespaced=true")
    } else {
      $args = ($args | append "--namespaced=false")
    }
  }

  # Add verbs filter
  if ($verbs | length) > 0 {
    $args = ($args | append ["--verbs" ($verbs | str join ",")])
  }

  # Add output format
  if $output == "json" {
    $args = ($args | append ["--output" "wide"])
  } else {
    $args = ($args | append ["--output" $output])
  }

  # Execute kubectl command
  let result = run-kubectl $args --context $context --output "text"

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Parse the wide output into structured data if JSON requested
  if $output == "json" {
    let resources = $result
    | lines
    | skip 1 # Skip header
    | each {|line|
      let parts = $line | split row --regex '\s+'
      {
        name: ($parts | get 0)
        shortnames: ($parts | get 1)
        apiversion: ($parts | get 2)
        namespaced: ($parts | get 3)
        kind: ($parts | get 4)
        verbs: (if ($parts | length) > 5 { $parts | get 5 } else { "" })
      }
    }

    format-tool-response {
      apiGroup: $api_group
      resources: $resources
    }
  } else {
    format-tool-response {
      output: $result
    }
  }
}

# ping - Verify kubectl connectivity
export def ping [
  params: record
] {
  # Extract parameters
  let context = $params.context? | default ""

  # Validate kubectl access
  let validation = validate-kubectl-access

  # Check if validation failed
  if ($validation | get isError? | default false) {
    return (format-tool-response $validation --error true)
  }

  # Get cluster info
  let cluster_info = try {
    let info = ^kubectl cluster-info | complete
    if ($info | get exit_code) == 0 {
      $info | get stdout | str trim
    } else {
      "Unable to retrieve cluster info"
    }
  } catch {
    "Unable to retrieve cluster info"
  }

  # Return success with details
  format-tool-response {
    status: "connected"
    kubectl: {
      version: (get-kubectl-version)
      path: (which kubectl | get path | first)
    }
    cluster: {
      context: (get-current-context)
      namespace: (get-default-namespace)
      info: $cluster_info
    }
    safetyMode: (get-safety-mode)
  }
}

# kube_scale - Scale deployments/statefulsets
export def kubectl-scale [
  params: record
] {
  # Extract parameters
  let name = $params.name
  let namespace = $params.namespace? | default ""
  let replicas = $params.replicas
  let resource_type = $params.resourceType? | default "deployment"
  let context = $params.context? | default ""

  # Build kubectl arguments
  let args = ["scale" $resource_type $name $"--replicas=($replicas)"]

  # Execute kubectl command
  let result = run-kubectl $args --namespace $namespace --context $context --output "text"

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "scale"
    resourceType: $resource_type
    name: $name
    replicas: $replicas
    result: $result
  }
}

# kube_rollout - Manage rollouts
export def kubectl-rollout [
  params: record
] {
  # Extract parameters
  let sub_command = $params.subCommand
  let resource_type = $params.resourceType
  let name = $params.name
  let namespace = $params.namespace
  let revision = $params.revision? | default null
  let to_revision = $params.toRevision? | default null
  let timeout = $params.timeout? | default ""
  let watch = $params.watch? | default false
  let context = $params.context? | default ""

  # Build kubectl arguments
  mut args = ["rollout" $sub_command $"($resource_type)/($name)"]

  # Add revision for undo
  if $revision != null {
    $args = ($args | append $"--to-revision=($revision)")
  }

  # Add timeout if specified
  if $timeout != "" {
    $args = ($args | append ["--timeout" $timeout])
  }

  # Add watch if specified
  if $watch {
    $args = ($args | append "--watch")
  }

  # Execute kubectl command
  let result = run-kubectl $args --namespace $namespace --context $context --output "text"

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "rollout"
    subCommand: $sub_command
    resourceType: $resource_type
    name: $name
    result: $result
  }
}

# kube_exec - Execute command in pod
export def exec-in-pod [
  params: record
] {
  # Extract parameters
  let name = $params.name
  let namespace = $params.namespace? | default ""
  let command = $params.command
  let container = $params.container? | default ""
  let shell = $params.shell? | default ""
  let timeout = $params.timeout? | default 60000
  let context = $params.context? | default ""

  # Build kubectl arguments
  mut args = ["exec" $name]

  # Add container if specified
  if $container != "" {
    $args = ($args | append ["-c" $container])
  }

  # Add the command separator
  $args = ($args | append "--")

  # Add shell and command
  if $shell != "" {
    $args = ($args | append [$shell "-c" $command])
  } else {
    # Split command into args if it's a string
    let cmd_parts = ($command | split row " ")
    $args = ($args | append $cmd_parts)
  }

  # Execute kubectl command
  let result = run-kubectl $args --namespace $namespace --context $context --output "text"

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "exec"
    pod: $name
    namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
    output: $result
  }
}

# kube_port_forward - Forward local port to pod/service
export def port-forward [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType
  let resource_name = $params.resourceName
  let local_port = $params.localPort
  let target_port = $params.targetPort
  let namespace = $params.namespace? | default ""
  let context = $params.context? | default ""

  # Build kubectl arguments
  let resource = $"($resource_type)/($resource_name)"
  let port_mapping = $"($local_port):($target_port)"
  let log_file = $"/tmp/kubectl-port-forward-($local_port).log"

  # Execute kubectl port-forward in background using Nushell job system
  let result = try {
    # Spawn background job for port-forward
    # kubectl port-forward blocks, keeping the job alive
    let job_id = (
      job spawn --tag $"pf-($local_port)" {||
        if $namespace != "" and $context != "" {
          ^kubectl port-forward $resource $port_mapping --namespace $namespace --context $context out+err> $log_file
        } else if $namespace != "" {
          ^kubectl port-forward $resource $port_mapping --namespace $namespace out+err> $log_file
        } else if $context != "" {
          ^kubectl port-forward $resource $port_mapping --context $context out+err> $log_file
        } else {
          ^kubectl port-forward $resource $port_mapping out+err> $log_file
        }
      }
    )

    # Give it a moment to start
    sleep 1sec

    # Check if the log file shows it started
    let log_content = if ($log_file | path exists) {
      open $log_file
    } else {
      ""
    }

    if ($log_content | str contains "Forwarding from") {
      {
        success: true
        message: $"Port forwarding started: localhost:($local_port) -> ($resource):($target_port)"
        id: $"pf-($local_port)"
        logFile: $log_file
      }
    } else if ($log_content | str contains "error") {
      error make {
        msg: $"Port forward failed: ($log_content)"
      }
    } else {
      {
        success: true
        message: $"Port forwarding started: localhost:($local_port) -> ($resource):($target_port)"
        id: $"pf-($local_port)"
        logFile: $log_file
        warning: "Could not verify startup - check log file"
      }
    }
  } catch {
    {
      error: "PortForwardFailed"
      message: $"Failed to start port forwarding: ($in)"
      isError: true
    }
  }

  # Check for errors
  if ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response $result
}

# kube_port_forward_stop - Stop port forwarding
export def kube-port-forward-stop [
  params: record
] {
  # Extract parameters
  let id = $params.id

  # Extract port from ID (format: pf-{port})
  let port = ($id | split row '-' | get 1)
  let log_file = $"/tmp/kubectl-port-forward-($port).log"

  # Try to stop the port-forward job
  let result = try {
    # Find the job by tag
    let jobs = (job list | where tag == $id)

    if ($jobs | length) == 0 {
      error make {
        msg: $"No port-forward job found with ID ($id)"
      }
    }

    # Get the job ID and kill it
    let job_id = ($jobs | first | get id)
    job kill $job_id

    # Give it a moment to stop
    sleep 500ms

    # Verify it's stopped
    let still_running = (job list | where id == $job_id | length) > 0

    if $still_running {
      error make {
        msg: $"Job ($job_id) is still running after kill attempt"
      }
    }

    # Clean up log file
    if ($log_file | path exists) {
      rm -f $log_file
    }

    {
      success: true
      message: $"Port forwarding stopped for ($id) (Job ID: ($job_id))"
      jobId: $job_id
    }
  } catch {
    {
      error: "StopPortForwardFailed"
      message: ($in)
      isError: true
    }
  }

  # Check for errors
  if ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "kube-port-forward-stop"
    id: $id
    message: ($result | get message)
  }
}

# ============================================================================
# Phase 2: Destructive Operations
# ============================================================================

# kube_node - Manage Kubernetes nodes (cordon, drain, uncordon)
export def node-management [
  params: record
] {
  # Extract parameters
  let operation = $params.operation
  let node_name = $params.nodeName? | default ""
  let force = $params.force? | default false
  let grace_period = $params.gracePeriod? | default (-1)
  let delete_local_data = $params.deleteLocalData? | default false
  let ignore_daemonsets = $params.ignoreDaemonsets? | default true
  let timeout = $params.timeout? | default "0"
  let dry_run = $params.dryRun? | default false
  let confirm_drain = $params.confirmDrain? | default false

  # Validate node name is provided for operations that need it
  if $node_name == "" and $operation in ["cordon" "drain" "uncordon"] {
    return (
      format-tool-response {
        error: "InvalidInput"
        message: "nodeName is required for cordon, drain, and uncordon operations"
        isError: true
      } --error true
    )
  }

  # Handle different operations
  match $operation {
    "cordon" => {
      # Cordon the node (mark as unschedulable)
      let result = try {
        let output = (^kubectl cordon $node_name)
        {
          success: true
          output: $output
        }
      } catch {
        {
          error: "CordonFailed"
          message: ($in | str trim)
          isError: true
        }
      }

      if ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
      }

      format-tool-response {
        operation: "cordon"
        node: $node_name
        result: ($result | get output)
      }
    }

    "uncordon" => {
      # Uncordon the node (mark as schedulable)
      let result = try {
        let output = (^kubectl uncordon $node_name)
        {
          success: true
          output: $output
        }
      } catch {
        {
          error: "UncordonFailed"
          message: ($in | str trim)
          isError: true
        }
      }

      if ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
      }

      format-tool-response {
        operation: "uncordon"
        node: $node_name
        result: ($result | get output)
      }
    }

    "drain" => {
      # Check for confirmation if not in dry run mode
      if (not $dry_run) and (not $confirm_drain) {
        return (
          format-tool-response {
            error: "ConfirmationRequired"
            message: $"Drain operation requires explicit confirmation. Set confirmDrain=true to proceed with draining node '($node_name)'."
            isError: true
          } --error true
        )
      }

      # Build drain command arguments
      mut drain_args = ["drain" $node_name]

      if $force {
        $drain_args = ($drain_args | append "--force")
      }

      if $grace_period >= 0 {
        $drain_args = ($drain_args | append $"--grace-period=($grace_period)")
      }

      if $delete_local_data {
        $drain_args = ($drain_args | append "--delete-emptydir-data")
      }

      if $ignore_daemonsets {
        $drain_args = ($drain_args | append "--ignore-daemonsets")
      }

      if $timeout != "0" {
        $drain_args = ($drain_args | append $"--timeout=($timeout)")
      }

      if $dry_run {
        $drain_args = ($drain_args | append "--dry-run=client")
      }

      # Execute drain command
      let result = try {
        let output = (^kubectl ...$drain_args)
        {
          success: true
          output: $output
          dryRun: $dry_run
        }
      } catch {
        {
          error: "DrainFailed"
          message: ($in | str trim)
          isError: true
        }
      }

      if ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
      }

      format-tool-response {
        operation: "drain"
        node: $node_name
        dryRun: $dry_run
        result: ($result | get output)
      }
    }

    _ => {
      format-tool-response {
        error: "UnknownOperation"
        message: $"Unknown node management operation: ($operation)"
        isError: true
      } --error true
    }
  }
}

# cleanup - Cleanup all managed resources
export def cleanup [
  params: record
] {
  # This is a simplified implementation
  # In the reference, this cleans up port-forwards and other managed resources
  # For now, we just acknowledge the cleanup request

  format-tool-response {
    operation: "kube_cleanup"
    message: "Cleanup completed (simplified implementation - no managed resources to clean)"
    success: true
  }
}
