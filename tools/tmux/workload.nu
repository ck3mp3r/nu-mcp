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
    # Note: pane-level options (-pt) require just the pane ID, not session:pane
    try {
      exec_tmux_command ['set-option' '-pt' $pane_id '@mcp_tmux' 'true']
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
  # Extract the appropriate target for the level
  # For panes: need just the pane ID (%N) from targets like "session:%4" or "session:window.%4"
  # For windows: use full session:window target
  # For sessions: use just session name
  let check_target = if $level == "pane" {
    # Extract pane ID - it's after the last '.' or ':' 
    let parts = $target | split row ":"
    let last_part = $parts | last
    if ($last_part | str contains ".") {
      $last_part | split row "." | last
    } else {
      $last_part
    }
  } else {
    $target
  }

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
    ['show-options' '-t' $check_target '@mcp_tmux']
  } else {
    ['show-options' $"($flag)t" $check_target '@mcp_tmux']
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
        error: $"Resource '($target)' was not created by MCP - missing @mcp_tmux marker."
      }
    }
  } catch {
    # show-options returns non-zero exit code if option doesn't exist
    {
      owned: false
      error: $"Resource '($target)' was not created by MCP - no @mcp_tmux marker found."
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
# Returns: Record with 'success' boolean and optional 'error'/'message'
#   { success: true } - Force flag is true, operation can proceed
#   { success: false, error: "...", message: "..." } - Force flag missing/false
export def validate-force-flag [
  force: bool
  operation: string
  resource: string
] {
  if $force != true {
    {
      success: false
      error: "Destructive operation requires explicit --force flag"
      message: $"Operation '($operation)' will permanently delete '($resource)'. Set force=true to proceed."
    }
  } else {
    {success: true}
  }
}

# =============================================================================
# Destructive Operations (Phase 3: kill operations with safety checks)
# =============================================================================

# Kill a tmux pane
#
# DESTRUCTIVE OPERATION - Can only destroy MCP-created panes (marked with @mcp_tmux).
# Requires explicit --force true flag.
#
# Parameters:
#   session - Session name or ID
#   --window - Optional window name or ID
#   --pane - Pane ID to kill (required)
#   --force - REQUIRED: Must be true to confirm destruction
#
# Returns: JSON with success status or error message
export def kill_pane [
  session: string
  --window: string
  --pane: string
  --force # Boolean flag - true if present, false if not
] {
  # Validate pane parameter
  if $pane == null {
    return (
      {
        success: false
        error: "Missing required parameter: pane"
        message: "You must specify --pane with the pane ID to kill (e.g., --pane '%4')"
      } | to json
    )
  }

  # Build target (session:window.pane or session:pane)
  let target = if $window != null {
    $"($session):($window).($pane)"
  } else {
    $"($session):($pane)"
  }

  # Safety check 1: Validate force flag
  let force_check = validate-force-flag $force "kill_pane" $target
  if $force_check.success != true {
    return ($force_check | to json)
  }

  # Safety check 2: Verify MCP ownership
  let ownership_check = check-mcp-ownership $target "pane"
  if $ownership_check.owned != true {
    return (
      {
        success: false
        error: "Cannot destroy user-created resource"
        message: $ownership_check.error
        resource: $target
      } | to json
    )
  }

  # Both safety checks passed - execute kill-pane
  # Note: kill-pane -t requires just the pane ID, not the full session:pane target
  try {
    exec_tmux_command ['kill-pane' '-t' $pane]
    {
      success: true
      pane: $pane
      message: $"Killed pane '($pane)' in session '($session)'"
    } | to json
  } catch {
    {
      success: false
      error: $"Failed to kill pane '($pane)'"
      message: "Could not kill pane. It may no longer exist."
      resource: $target
    } | to json
  }
}

# Kill a tmux window
#
# DESTRUCTIVE OPERATION - Can only destroy MCP-created windows (marked with @mcp_tmux).
# Requires explicit --force flag.
#
# Parameters:
#   session - Session name or ID
#   --window - Window name or ID to kill (required)
#   --force - REQUIRED: Must be true to confirm destruction
#
# Returns: JSON with success status or error message
export def kill_window [
  session: string
  --window: string
  --force # Boolean flag - true if present, false if not
] {
  # Validate window parameter
  if $window == null {
    return (
      {
        success: false
        error: "Missing required parameter: window"
        message: "You must specify --window with the window ID or name to kill (e.g., --window '@2' or --window 'frontend')"
      } | to json
    )
  }

  # Build target (session:window)
  let target = $"($session):($window)"

  # Safety check 1: Validate force flag
  let force_check = validate-force-flag $force "kill_window" $target
  if $force_check.success != true {
    return ($force_check | to json)
  }

  # Safety check 2: Verify MCP ownership
  let ownership_check = check-mcp-ownership $target "window"
  if $ownership_check.owned != true {
    return (
      {
        success: false
        error: "Cannot destroy user-created resource"
        message: $ownership_check.error
        resource: $target
      } | to json
    )
  }

  # Both safety checks passed - execute kill-window
  try {
    exec_tmux_command ['kill-window' '-t' $target]
    {
      success: true
      window: $window
      message: $"Killed window '($window)' in session '($session)'"
    } | to json
  } catch {
    {
      success: false
      error: $"Failed to kill window '($window)'"
      message: "Could not kill window. It may no longer exist."
      resource: $target
    } | to json
  }
}

# Kill a tmux session
#
# DESTRUCTIVE OPERATION - Can only destroy MCP-created sessions (marked with @mcp_tmux).
# Requires explicit --force flag.
#
# Parameters:
#   session - Session name or ID to kill
#   --force - REQUIRED: Must be true to confirm destruction
#
# Returns: JSON with success status or error message
export def kill_session [
  session: string
  --force # Boolean flag - true if present, false if not
] {
  # Safety check 1: Validate force flag
  let force_check = validate-force-flag $force "kill_session" $session
  if $force_check.success != true {
    return ($force_check | to json)
  }

  # Safety check 2: Verify MCP ownership
  let ownership_check = check-mcp-ownership $session "session"
  if $ownership_check.owned != true {
    return (
      {
        success: false
        error: "Cannot destroy user-created resource"
        message: $ownership_check.error
        resource: $session
      } | to json
    )
  }

  # Both safety checks passed - execute kill-session
  try {
    exec_tmux_command ['kill-session' '-t' $session]
    {
      success: true
      session: $session
      message: $"Killed session '($session)'"
    } | to json
  } catch {
    {
      success: false
      error: $"Failed to kill session '($session)'"
      message: "Could not kill session. It may no longer exist."
      resource: $session
    } | to json
  }
}

# =============================================================================
# Layout Management (Phase 3: non-destructive pane arrangement)
# =============================================================================

# Select a layout for panes in a tmux window
#
# Arranges panes in the window according to one of five predefined layouts.
# This is a non-destructive operation that only changes visual arrangement.
#
# Parameters:
#   session - Session name or ID
#   layout - Layout name (even-horizontal, even-vertical, main-horizontal, main-vertical, tiled)
#   --window - Optional window name or ID (defaults to current window)
#
# Returns: JSON with success status or error message
export def select_layout [
  session: string
  layout: string
  --window: string
] {
  # Validate layout parameter
  let valid_layouts = [
    "even-horizontal"
    "even-vertical"
    "main-horizontal"
    "main-vertical"
    "tiled"
  ]

  if $layout not-in $valid_layouts {
    return (
      {
        success: false
        error: $"Invalid layout: ($layout)"
        message: $"Layout must be one of: ($valid_layouts | str join ', ')"
      } | to json
    )
  }

  # Build target (session:window or just session:)
  let target = if $window != null {
    $"($session):($window)"
  } else {
    $"($session):"
  }

  # Execute select-layout command
  try {
    exec_tmux_command ['select-layout' '-t' $target $layout]
    {
      success: true
      layout: $layout
      session: $session
      window: ($window | default "current")
      message: $"Applied '($layout)' layout to window in session '($session)'"
    } | to json
  } catch {
    {
      success: false
      error: $"Failed to apply layout '($layout)'"
      message: "Could not apply layout. Verify the session and window exist with list_sessions."
      resource: $target
    } | to json
  }
}

# Create a new tmux session with MCP ownership marker
#
# Creates a detached session by default to avoid disrupting user's current work.
# Automatically marks the session with @mcp_tmux user option for safe lifecycle management.
#
# Parameters:
#   name - Session name (must be unique)
#   --window-name - Optional: Name for initial window
#   --directory - Optional: Starting directory
#   --detached - Optional: Create detached (default: true)
#
# Returns: JSON with session info or error message
export def create-session [
  name: string # Session name (must be unique)
  --window-name: string # Optional: Name for initial window
  --directory: string # Optional: Starting directory
  --detached = true # Optional: Create detached (default: true)
] {
  # Check if session already exists
  let duplicate_exists = try {
    let existing_sessions = exec_tmux_command ['list-sessions' '-F' '#{session_name}']
    let session_list = $existing_sessions | lines
    $name in $session_list
  } catch {
    # If list-sessions fails (no server running), we can proceed
    false
  }

  if $duplicate_exists {
    {
      success: false
      error: "SessionExists"
      message: $"Session '($name)' already exists"
    } | to json
  } else {
    # Build tmux command
    mut cmd_args = ['new-session' '-s' $name]

    # Detached or attached
    if $detached {
      $cmd_args = ($cmd_args | append '-d')
    }

    # Initial window name
    if $window_name != null {
      $cmd_args = ($cmd_args | append ['-n' $window_name])
    }

    # Starting directory
    if $directory != null {
      $cmd_args = ($cmd_args | append ['-c' $directory])
    }

    # Create the session
    try {
      exec_tmux_command $cmd_args

      # Mark session as MCP-created (session-level user option)
      exec_tmux_command ['set-option' '-t' $name '@mcp_tmux' 'true']

      # Get session info
      let session_info = exec_tmux_command ['display-message' '-t' $name '-p' '#{session_id}']

      let mode = if $detached { "detached" } else { "attached" }

      {
        success: true
        session_id: ($session_info | str trim)
        session_name: $name
        message: $"Created session '($name)' \(($mode))"
      } | to json
    } catch {|err|
      {
        success: false
        error: "CreationFailed"
        message: $"Failed to create session: ($err.msg)"
      } | to json
    }
  }
}
