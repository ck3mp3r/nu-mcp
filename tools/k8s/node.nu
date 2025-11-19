# Kubernetes MCP Tool - Node Operations
# Implementation for kube_node

use utils.nu *

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
