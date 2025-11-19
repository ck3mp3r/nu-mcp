# Kubernetes MCP Tool - Port Forward Operations
# Implementations for kube_port_forward, kube_port_forward_stop

use utils.nu *

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
  let pid_file = $"/tmp/kubectl-port-forward-($local_port).pid"

  # Execute kubectl port-forward in background as a detached process
  let result = try {
    # Build the kubectl command
    mut cmd = ["kubectl" "port-forward" $resource $port_mapping]

    if $namespace != "" {
      $cmd = ($cmd | append ["--namespace" $namespace])
    }

    if $context != "" {
      $cmd = ($cmd | append ["--context" $context])
    }

    let cmd_str = ($cmd | str join " ")

    # Start the process in the background using bash
    # We need to use bash/sh to properly background the process and capture PID
    let bash_cmd = $"($cmd_str) > ($log_file) 2>&1 & echo $! > ($pid_file)"
    ^bash -c $bash_cmd

    # Give it a moment to start
    sleep 1sec

    # Read the PID
    let pid = if ($pid_file | path exists) {
      open $pid_file | str trim | into int
    } else {
      error make {
        msg: "Failed to capture process PID"
      }
    }

    # Verify the process is running using Nushell's ps
    let is_running = (ps | where pid == $pid | length) > 0

    if not $is_running {
      # Check log for errors
      let log_content = if ($log_file | path exists) {
        open $log_file
      } else {
        "No log file created"
      }

      error make {
        msg: $"Port forward process failed to start: ($log_content)"
      }
    }

    # Check if the log file shows it started successfully
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
        pid: $pid
        logFile: $log_file
        pidFile: $pid_file
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
        pid: $pid
        logFile: $log_file
        pidFile: $pid_file
        warning: "Could not verify startup in logs - but process is running"
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
  let pid_file = $"/tmp/kubectl-port-forward-($port).pid"

  # Try to stop the port-forward process
  let result = try {
    # Check if PID file exists
    if not ($pid_file | path exists) {
      error make {
        msg: $"No port-forward process found with ID ($id) - PID file not found"
      }
    }

    # Read the PID
    let pid = (open $pid_file | str trim | into int)

    # Check if process is running using Nushell's ps
    let is_running = (ps | where pid == $pid | length) > 0

    if not $is_running {
      # Process already stopped, just clean up files
      if ($log_file | path exists) {
        rm -f $log_file
      }
      rm -f $pid_file

      {
        success: true
        message: $"Port forwarding for ($id) was already stopped. Cleaned up files."
        pid: $pid
        wasRunning: false
      }
    } else {
      # Kill the process using external kill command
      ^kill $pid

      # Give it a moment to stop
      sleep 500ms

      # Verify it's stopped
      let still_running = (ps | where pid == $pid | length) > 0

      if $still_running {
        # Try harder with SIGKILL
        ^kill -9 $pid
        sleep 200ms

        let really_still_running = (ps | where pid == $pid | length) > 0
        if $really_still_running {
          error make {
            msg: $"Process ($pid) is still running after kill attempts"
          }
        }
      }

      # Clean up files
      if ($log_file | path exists) {
        rm -f $log_file
      }
      rm -f $pid_file

      {
        success: true
        message: $"Port forwarding stopped for ($id) \(PID: ($pid)\)"
        pid: $pid
        wasRunning: true
      }
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
