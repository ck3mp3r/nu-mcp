# Kubernetes MCP Tool - Exec Operations
# Implementation for kube_exec

use utils.nu *

# kube_exec - Execute command in a pod
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
  let delegate = $params.delegate? | default false

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

  # Execute kubectl command
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
  format-tool-response {
    operation: "exec"
    pod: $name
    namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
    output: $result
  }
}
