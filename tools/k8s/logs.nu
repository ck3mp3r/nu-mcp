# Kubernetes MCP Tool - Logs Operations
# Implementation for kube_logs

use utils.nu *

# kube_logs - Get pod/container logs
export def kubectl-logs [
  params: record
] {
  # Extract parameters
  let resource_type = $params.resourceType? | default "pod"
  let name = $params.name? | default ""
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
  let delegate = $params.delegate? | default false

  # Validate: must have either name or labelSelector
  if $name == "" and $label_selector == "" {
    return (
      format-tool-response {
        error: "Either 'name' or 'labelSelector' parameter is required"
        message: "You must specify either a resource name or a label selector to get logs"
      } --error true
    )
  }

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

  # If delegating, return the command string
  if $delegate {
    return (
      {
        args: $args
        namespace: $namespace
        context: $context
        output: "text"
      } | build-kubectl-command
    )
  }

  # Execute kubectl command (logs are plain text)
  let result = {
    args: $args
    namespace: $namespace
    context: $context
    output: "text"
  } | run-kubectl

  # Check for errors
  if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  mut response = {
    resourceType: $resource_type
    namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
    logs: $result
  }

  # Add name if it was provided (not using label selector)
  if $name != "" {
    $response = ($response | insert name $name)
  }

  # Add label selector if it was used
  if $label_selector != "" {
    $response = ($response | insert labelSelector $label_selector)
  }

  # Add container if specified
  if $container != "" {
    $response = ($response | insert container $container)
  }

  format-tool-response $response
}
