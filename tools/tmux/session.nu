# Session and listing functions for tmux

use core.nu *

# List all tmux sessions with their windows and panes
export def list_sessions [] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Get sessions
    let cmd_args = ["list-sessions" "-F" "#{session_name}|#{session_created}|#{session_attached}|#{session_windows}"]
    let sessions = exec_tmux_command $cmd_args | lines

    if ($sessions | length) == 0 {
      return "No tmux sessions found"
    }

    mut all_items = []

    for session_line in $sessions {
      let parts = $session_line | split row "|"
      let session_name = $parts | get 0
      let created = $parts | get 1
      let attached = $parts | get 2
      let window_count = $parts | get 3

      let status = if $attached == "1" { "attached" } else { "detached" }

      # Get windows for this session
      let cmd_args = ["list-windows" "-t" $session_name "-F" "#{window_index}|#{window_name}|#{window_panes}"]
      let windows = exec_tmux_command $cmd_args | lines

      for window_line in $windows {
        let window_parts = $window_line | split row "|"
        let window_index = $window_parts | get 0
        let window_name = $window_parts | get 1
        let pane_count = $window_parts | get 2

        # Get panes for this window
        let cmd_args = ["list-panes" "-t" $"($session_name):($window_index)" "-F" "#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}"]
        let panes = exec_tmux_command $cmd_args | lines

        for pane_line in $panes {
          let pane_parts = $pane_line | split row "|"
          let pane_index = $pane_parts | get 0
          let current_command = $pane_parts | get 1
          let is_active = $pane_parts | get 2
          let pane_title = $pane_parts | get 3

          let pane_status = if $is_active == "1" { "active" } else { "inactive" }
          let title = if $pane_title != "" { $pane_title } else { "" }

          $all_items = (
            $all_items | append {
              session: $session_name
              session_status: $status
              window: $window_index
              window_name: $window_name
              pane: $pane_index
              pane_title: $title
              command: $current_command
              pane_status: $pane_status
            }
          )
        }
      }
    }

    $all_items | table
  } catch {
    "Error: Failed to list tmux sessions. Make sure tmux is running."
  }
}

# Get detailed information about a specific tmux session
export def get_session_info [session: string] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Get session info
    let cmd_args = ["display-message" "-t" $session "-p" "#{session_name}|#{session_created}|#{session_attached}|#{session_windows}|#{session_group}|#{session_id}"]
    let session_info = exec_tmux_command $cmd_args | str trim
    let parts = $session_info | split row "|"

    let session_name = $parts | get 0
    let created_timestamp = $parts | get 1
    let attached = $parts | get 2
    let window_count = $parts | get 3
    let session_group = $parts | get 4
    let session_id = $parts | get 5

    let status = if $attached == "1" { "attached" } else { "detached" }
    let created_date = $created_timestamp | into int | into datetime

    mut output = [
      $"Session Information for: ($session_name)"
      $"Session ID: ($session_id)"
      $"Status: ($status)"
      $"Created: ($created_date)"
      $"Windows: ($window_count)"
    ]

    if $session_group != "" {
      $output = ($output | append $"Group: ($session_group)")
    }

    $output = ($output | append "")

    # Get all panes across all windows as a table
    let cmd_args = ["list-windows" "-t" $session "-F" "#{window_index}|#{window_name}|#{window_active}"]
    let windows = exec_tmux_command $cmd_args | lines

    mut all_panes = []

    for window_line in $windows {
      let window_parts = $window_line | split row "|"
      let window_index = $window_parts | get 0
      let window_name = $window_parts | get 1
      let window_is_active = $window_parts | get 2

      # Get detailed pane information for this window
      let cmd_args = ["list-panes" "-t" $"($session):($window_index)" "-F" "#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}"]
      let panes = exec_tmux_command $cmd_args | lines

      for pane_line in $panes {
        let pane_parts = $pane_line | split row "|"
        let pane_index = $pane_parts | get 0
        let pane_title = $pane_parts | get 1
        let current_command = $pane_parts | get 2
        let pane_is_active = $pane_parts | get 3
        let current_path = $pane_parts | get 4
        let pane_pid = $pane_parts | get 5

        # Determine custom name vs auto-generated title
        let looks_auto_generated = (
          ($pane_title | str contains "> ") or
          ($pane_title | str contains "✳") or
          ($pane_title | str contains "/") or
          ($pane_title == $current_path) or
          ($pane_title == "")
        )

        let custom_name = if $looks_auto_generated or ($pane_title | str length) > 20 {
          ""
        } else {
          $pane_title
        }

        let status = if $window_is_active == "1" and $pane_is_active == "1" {
          "active"
        } else if $pane_is_active == "1" {
          "current"
        } else {
          "inactive"
        }

        let pane_record = {
          window: $window_index
          window_name: $window_name
          pane: $pane_index
          name: $custom_name
          process: $current_command
          directory: ($current_path | path basename)
          full_path: $current_path
          pid: $pane_pid
          status: $status
          target: $"($session):($window_index).($pane_index)"
        }

        $all_panes = ($all_panes | append $pane_record)
      }
    }

    # Create expanded nested table structure
    $output = ($output | append "Windows and Panes:")
    $output = ($output | append "")

    # Use group-by to create proper nested table with expansion
    let nested_table = $all_panes | select window window_name pane process directory status | group-by window window_name --to-table | update items {|row| $row.items | select pane process directory status }

    let table_output = $nested_table | table --expand
    $output = ($output | append $table_output)

    $output | str join (char newline)
  } catch {
    $"Error: Failed to get session info for '($session)'. Check that the session exists."
  }
}

# List all panes in a session as a table
export def list_panes [session: string] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Get all windows
    let cmd_args = ["list-windows" "-t" $session "-F" "#{window_index}|#{window_name}|#{window_active}"]
    let windows = exec_tmux_command $cmd_args | lines

    mut all_panes = []

    for window_line in $windows {
      let window_parts = $window_line | split row "|"
      let window_index = $window_parts | get 0
      let window_name = $window_parts | get 1
      let window_is_active = $window_parts | get 2

      # Get detailed pane information for this window
      let cmd_args = ["list-panes" "-t" $"($session):($window_index)" "-F" "#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}"]
      let panes = exec_tmux_command $cmd_args | lines

      for pane_line in $panes {
        let pane_parts = $pane_line | split row "|"
        let pane_index = $pane_parts | get 0
        let pane_title = $pane_parts | get 1
        let current_command = $pane_parts | get 2
        let pane_is_active = $pane_parts | get 3
        let current_path = $pane_parts | get 4
        let pane_pid = $pane_parts | get 5

        # Determine custom name vs auto-generated title
        let looks_auto_generated = (
          ($pane_title | str contains "> ") or
          ($pane_title | str contains "✳") or
          ($pane_title | str contains "/") or
          ($pane_title == $current_path) or
          ($pane_title == "")
        )

        let custom_name = if $looks_auto_generated or ($pane_title | str length) > 20 {
          ""
        } else {
          $pane_title
        }

        let status = if $window_is_active == "1" and $pane_is_active == "1" {
          "active"
        } else if $pane_is_active == "1" {
          "current"
        } else {
          "inactive"
        }

        let pane_record = {
          window: $window_index
          window_name: $window_name
          pane: $pane_index
          name: $custom_name
          process: $current_command
          directory: ($current_path | path basename)
          full_path: $current_path
          pid: $pane_pid
          status: $status
          target: $"($session):($window_index).($pane_index)"
        }

        $all_panes = ($all_panes | append $pane_record)
      }
    }

    # Create proper nested table structure with expansion
    $all_panes | select window window_name pane process directory status | group-by window window_name --to-table | update items {|row| $row.items | select pane process directory status } | table --expand
  } catch {
    $"Error: Failed to list panes for session '($session)'. Check that the session exists."
  }
}