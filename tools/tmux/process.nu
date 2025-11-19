# Process information functions for tmux

use core.nu *
use search.nu *

# Helper function to resolve pane target with name/context support
def resolve_pane_target_with_search [session: string window?: string pane?: string] {
  # If pane looks like a name (not just numbers), try to find it by name or context
  if $pane != null and not ($pane =~ '^[0-9]+$') {
    # First try finding by explicit name
    let find_result = find_pane_by_name $session $pane
    if not ($find_result | str starts-with "No pane named") and not ($find_result | str starts-with "Error:") {
      # Extract target from the table result - get the first target found
      let target_info = $find_result | from json | first
      return $target_info.target
    }

    # If name search failed, try context search
    let context_result = find_pane_by_context $session $pane
    if not ($context_result | str starts-with "No pane matching") and not ($context_result | str starts-with "Error:") {
      # Extract target from the table result - get the first target found
      let target_info = $context_result | from json | first
      return $target_info.target
    }

    return null
  }

  # Use basic ID-based resolution for numeric panes
  return (resolve_pane_target $session $window $pane)
}

# Get information about the running process in a specific tmux pane
export def get_pane_process [session: string window?: string pane?: string] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Resolve the target (supports pane names)
    let target = resolve_pane_target_with_search $session $window $pane
    if $target == null {
      return $"Error: Could not find pane '($pane)' in session '($session)'"
    }

    # Get pane information including PID and command
    let cmd_args = ["display-message" "-t" $target "-p" "#{pane_index}|#{pane_current_command}|#{pane_pid}|#{pane_current_path}|#{pane_width}x#{pane_height}|#{pane_active}"]
    let pane_info = exec_tmux_command $cmd_args | str trim
    let parts = $pane_info | split row "|"

    let pane_index = $parts | get 0
    let current_command = $parts | get 1
    let pane_pid = $parts | get 2
    let current_path = $parts | get 3
    let pane_size = $parts | get 4
    let is_active = $parts | get 5

    let active_status = if $is_active == "1" { "active" } else { "inactive" }

    # Try to get more detailed process information
    let process_info = try {
      run-external "ps" "-p" $pane_pid "-o" "pid,ppid,command" | lines | skip 1 | first
    } catch {
      $"PID ($pane_pid): ($current_command)"
    }

    {
      target: $target
      pane_index: $pane_index
      status: $active_status
      size: $pane_size
      current_path: $current_path
      current_command: $current_command
      process_id: $pane_pid
      process_details: $process_info
    } | to json --indent 2
  } catch {
    $"Error: Failed to get pane process info for '($session)'. Check that the session/pane exists."
  }
}
