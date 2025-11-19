# Pane finding and search functions for tmux

use core.nu *

# Find a pane by its name/title across all windows in a session
export def find_pane_by_name [session: string pane_name: string] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Get all windows in the session
    let cmd_args = ["list-windows" "-t" $session "-F" "#{window_index}"]
    let windows = exec_tmux_command $cmd_args | lines

    mut found_panes = []

    for window_index in $windows {
      # Get panes in this window with their titles
      let cmd_args = ["list-panes" "-t" $"($session):($window_index)" "-F" "#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}"]
      let panes = exec_tmux_command $cmd_args | lines

      for pane_line in $panes {
        let parts = $pane_line | split row "|"
        let pane_index = $parts | get 0
        let pane_title = $parts | get 1
        let current_command = $parts | get 2
        let is_active = $parts | get 3
        let current_path = $parts | get 4

        # Check if this pane matches the name (case-insensitive)
        if ($pane_title | str downcase) == ($pane_name | str downcase) {
          let active_status = if $is_active == "1" { "active" } else { "inactive" }
          let pane_info = {
            session: $session
            window: $window_index
            pane: $pane_index
            title: $pane_title
            command: $current_command
            status: $active_status
            path: $current_path
            target: $"($session):($window_index).($pane_index)"
          }
          $found_panes = ($found_panes | append $pane_info)
        }
      }
    }

    if ($found_panes | length) == 0 {
      $"No pane named '($pane_name)' found in session '($session)'"
    } else {
      $found_panes | to json --indent 2
    }
  } catch {
    $"Error: Failed to search for pane '($pane_name)' in session '($session)'. Check that the session exists."
  }
}

# Find a pane by context (directory, command, description)
export def find_pane_by_context [session: string context: string] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Get all windows in the session
    let cmd_args = ["list-windows" "-t" $session "-F" "#{window_index}"]
    let windows = exec_tmux_command $cmd_args | lines

    mut found_panes = []
    let search_context = $context | str downcase

    for window_index in $windows {
      # Get panes in this window with detailed info
      let cmd_args = ["list-panes" "-t" $"($session):($window_index)" "-F" "#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}"]
      let panes = exec_tmux_command $cmd_args | lines

      for pane_line in $panes {
        let parts = $pane_line | split row "|"
        let pane_index = $parts | get 0
        let pane_title = $parts | get 1
        let current_command = $parts | get 2
        let is_active = $parts | get 3
        let current_path = $parts | get 4

        # Check if context matches any of: title, command, path segment, or directory name
        let title_lower = $pane_title | str downcase
        let command_lower = $current_command | str downcase
        let path_lower = $current_path | str downcase
        let dir_name = $current_path | path basename | str downcase

        let matches = (
          ($title_lower | str contains $search_context) or
          ($command_lower | str contains $search_context) or
          ($path_lower | str contains $search_context) or
          ($dir_name == $search_context)
        )

        if $matches {
          let active_status = if $is_active == "1" { "active" } else { "inactive" }
          let pane_info = {
            session: $session
            window: $window_index
            pane: $pane_index
            title: $pane_title
            command: $current_command
            status: $active_status
            path: $current_path
            target: $"($session):($window_index).($pane_index)"
          }
          $found_panes = ($found_panes | append $pane_info)
        }
      }
    }

    if ($found_panes | length) == 0 {
      $"No pane matching context '($context)' found in session '($session)'"
    } else {
      $found_panes | to json --indent 2
    }
  } catch {
    $"Error: Failed to search for context '($context)' in session '($session)'. Check that the session exists."
  }
}
