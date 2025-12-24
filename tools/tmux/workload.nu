# Window and Pane Management Operations for tmux
# Provides functions to create windows and split panes

use core.nu *

# Create a new window in a tmux session
#
# Parameters:
#   session - Session name or ID
#   --name - Optional window name
#   --directory - Optional working directory
#   --target - Optional target window index
#
# Returns: JSON with window info or error message
export def create_window [
  session: string
  --name: string
  --directory: string
  --target: int
] {
  # Build tmux command arguments
  mut cmd_args = ['new-window' '-t' $"($session):"]

  # Add optional name
  if $name != null {
    $cmd_args = ($cmd_args | append ['-n' $name])
  }

  # Add optional directory
  if $directory != null {
    $cmd_args = ($cmd_args | append ['-c' $directory])
  }

  # Add optional target index
  if $target != null {
    $cmd_args = ($cmd_args | append ['-t' $"($session):($target)"])
  }

  # Always detached and return format info
  $cmd_args = ($cmd_args | append ['-dPF' '#{window_id}:#{window_index}'])

  # Execute tmux command
  try {
    let output = exec_tmux_command $cmd_args | str trim

    # Parse output: "@id:index"
    let parts = $output | split row ':'

    if ($parts | length) >= 2 {
      let window_name = if $name != null { $name } else { "window" }
      {
        success: true
        window_id: ($parts | get 0)
        window_index: ($parts | get 1 | into int)
        message: $"Created window '($window_name)' in session '($session)'"
      } | to json
    } else {
      {
        success: false
        error: $"Unexpected output format: ($output)"
      } | to json
    }
  } catch {
    {
      success: false
      error: $"Failed to create window in session '($session)'"
      message: "Could not create window. Verify the session exists with list_sessions."
    } | to json
  }
}

# Split a pane in a tmux window
#
# Parameters:
#   session - Session name or ID
#   direction - Split direction: "horizontal" (left/right) or "vertical" (top/bottom)
#   --window - Optional window name or ID
#   --pane - Optional pane ID to split
#   --directory - Optional working directory
#   --size - Optional size percentage (default: 50)
#
# Returns: JSON with pane info or error message
export def split_pane [
  session: string
  direction: string
  --window: string
  --pane: string
  --directory: string
  --size: int
] {
  # Validate direction
  if $direction not-in ['horizontal' 'vertical'] {
    return (
      {
        success: false
        error: $"Invalid direction: ($direction)"
        message: "Direction must be 'horizontal' or 'vertical'"
      } | to json
    )
  }

  # Build target (session:window.pane or just session:)
  let target = if $window != null and $pane != null {
    $"($session):($window).($pane)"
  } else if $window != null {
    $"($session):($window)"
  } else if $pane != null {
    $"($session):.($pane)"
  } else {
    $"($session):"
  }

  # Build tmux command arguments
  mut cmd_args = ['split-window' '-t' $target]

  # Add direction flag
  if $direction == 'horizontal' {
    $cmd_args = ($cmd_args | append '-h')
  } else {
    $cmd_args = ($cmd_args | append '-v')
  }

  # Add optional directory
  if $directory != null {
    $cmd_args = ($cmd_args | append ['-c' $directory])
  }

  # Add optional size
  if $size != null {
    $cmd_args = ($cmd_args | append ['-p' ($size | into string)])
  }

  # Always detached and return pane ID
  $cmd_args = ($cmd_args | append ['-dPF' '#{pane_id}'])

  # Execute tmux command
  try {
    let output = exec_tmux_command $cmd_args | str trim

    {
      success: true
      pane_id: $output
      direction: $direction
      message: $"Split pane ($direction) in session '($session)'"
    } | to json
  } catch {
    {
      success: false
      error: $"Failed to split pane in session '($session)'"
      message: "Could not split pane. Verify the session exists with list_sessions."
    } | to json
  }
}
