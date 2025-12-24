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
      let window_id = $parts | get 0
      let window_index = $parts | get 1 | into int

      # Mark window as MCP-created using tmux user options
      try {
        exec_tmux_command ['set-option' '-wt' $"($session):($window_id)" '@mcp_tmux' 'true']
      } catch {
        # Continue even if marking fails - window is created
      }

      let window_name = if $name != null { $name } else { "window" }
      {
        success: true
        window_id: $window_id
        window_index: $window_index
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
    let pane_id = exec_tmux_command $cmd_args | str trim

    # Mark pane as MCP-created using tmux user options
    try {
      exec_tmux_command ['set-option' '-pt' $"($session):($pane_id)" '@mcp_tmux' 'true']
    } catch {
      # Continue even if marking fails - pane is created
    }

    {
      success: true
      pane_id: $pane_id
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

# =============================================================================
# Safety Helpers (Phase 3: ownership verification for destructive operations)
# =============================================================================

# Check if a tmux resource (pane, window, session) was created by MCP
#
# This helper verifies ownership by checking for the @mcp_tmux user option marker.
# Only resources marked by MCP can be destroyed by destructive operations.
#
# Parameters:
#   target - Target identifier (e.g., "session:pane_id" or "session:@window_id")
#   level - Resource level: "pane", "window", or "session"
#
# Returns: Record with 'owned' boolean and optional 'error' message
#   { owned: true } - Resource is MCP-created
#   { owned: false, error: "..." } - Resource not MCP-created or check failed
export def check-mcp-ownership [
  target: string
  level: string
] {
  # Build show-options command based on level
  let flag = match $level {
    "pane" => "-p"
    "window" => "-w"
    "session" => ""
    _ => {
      return {
        owned: false
        error: $"Invalid level: ($level). Must be 'pane', 'window', or 'session'"
      }
    }
  }

  # Build command arguments
  let cmd_args = if $level == "session" {
    ['show-options' '-t' $target '@mcp_tmux']
  } else {
    ['show-options' $"($flag)t" $target '@mcp_tmux']
  }

  # Try to read the @mcp_tmux marker
  try {
    let output = exec_tmux_command $cmd_args | str trim

    # If successful, check if output contains the marker
    if ($output | str contains '@mcp_tmux') {
      {owned: true}
    } else {
      {
        owned: false
        error: $"Resource '($target)' was not created by MCP (missing @mcp_tmux marker)."
      }
    }
  } catch {
    # show-options returns non-zero exit code if option doesn't exist
    {
      owned: false
      error: $"Resource '($target)' was not created by MCP (no @mcp_tmux marker found)."
    }
  }
}

# Validate that the force flag is explicitly set to true for destructive operations
#
# All destructive operations (kill_pane, kill_window, kill_session) REQUIRE
# the user to explicitly set force=true to confirm the operation.
#
# Parameters:
#   force - The force flag value (must be exactly true)
#   operation - Operation name (for error messages)
#   resource - Resource identifier (for error messages)
#
# Returns: Record with 'valid' boolean and optional 'error'/'message'
#   { valid: true } - Force flag is true, operation can proceed
#   { valid: false, error: "...", message: "..." } - Force flag missing/false
export def validate-force-flag [
  force: bool
  operation: string
  resource: string
] {
  if $force != true {
    {
      valid: false
      error: "Destructive operation requires explicit --force flag"
      message: $"Operation '($operation)' will permanently delete '($resource)'. Set force=true to proceed."
    }
  } else {
    {valid: true}
  }
}
