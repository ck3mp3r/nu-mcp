# Command execution functions for tmux

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

# Send a command to a specific tmux pane
export def send_command [session: string command: string window?: string pane?: string] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Resolve the target (supports pane names)
    let target = resolve_pane_target_with_search $session $window $pane
    if $target == null {
      return $"Error: Could not find pane '($pane)' in session '($session)'"
    }

    # Send the command
    let cmd_args = ["send-keys" "-t" $target $command "Enter"]
    exec_tmux_command $cmd_args
    $"Command sent to ($target): ($command)"
  } catch {
    $"Error: Failed to send command to tmux session/pane. Check that the session '($session)' exists."
  }
}

# Capture content from a specific tmux pane
export def capture_pane [session: string window?: string pane?: string lines?: int] {
  if not (check_tmux) {
    return "Error: tmux is not installed or not available in PATH"
  }

  try {
    # Resolve the target (supports pane names)
    let target = resolve_pane_target_with_search $session $window $pane
    if $target == null {
      return $"Error: Could not find pane '($pane)' in session '($session)'"
    }

    # Build capture command
    mut cmd_args = ["capture-pane" "-t" $target "-p"]
    if $lines != null {
      $cmd_args = ($cmd_args | append ["-S" $"-($lines)"])
    }

    # Capture the pane content
    let content = exec_tmux_command $cmd_args | str trim

    $"Pane content from ($target):\n---\n($content)\n---"
  } catch {
    $"Error: Failed to capture pane content. Check that the session/pane '($session)' exists."
  }
}

# Send a command and capture its output with intelligent back-off polling
export def send_and_capture [session: string command: string window?: string pane?: string wait_seconds: number = 1 lines?: int] {
  # Capture initial state before sending command
  let initial_result = capture_pane $session $window $pane $lines
  if ($initial_result | str starts-with "Error:") {
    return $initial_result
  }
  let initial_content = $initial_result | lines | skip 2 | drop 1 | str join (char newline) | str trim

  # Send the command
  let send_result = send_command $session $command $window $pane
  if ($send_result | str starts-with "Error:") {
    return $send_result
  }

  # Poll for output with exponential back-off
  mut attempt = 0
  mut delay_ms = 100 # Start with 100ms
  let max_attempts = 10
  let max_wait_ms = ($wait_seconds * 1000) | into int
  mut total_waited_ms = 0

  loop {
    # Wait before capturing
    sleep ($delay_ms | into duration --unit ms)
    $total_waited_ms = $total_waited_ms + $delay_ms

    # Capture current content
    let capture_result = capture_pane $session $window $pane $lines
    if ($capture_result | str starts-with "Error:") {
      return $capture_result
    }
    let current_content = $capture_result | lines | skip 2 | drop 1 | str join (char newline) | str trim

    # Check if content has meaningfully changed
    let content_changed = ($current_content != $initial_content)
    let has_new_lines = ($current_content | lines | length) > ($initial_content | lines | length)
    let content_grew = ($current_content | str length) > ($initial_content | str length) + 10

    # Stop if we have meaningful new content or hit limits
    if $content_changed and ($has_new_lines or $content_grew) {
      let waited_sec = ($total_waited_ms / 1000.0)
      return $"Command executed: ($command)\nPolled for ($waited_sec) seconds until output appeared\n---\n($current_content)\n---"
    }

    $attempt = $attempt + 1

    # Check if we should give up
    if $attempt >= $max_attempts or $total_waited_ms >= $max_wait_ms {
      let waited_sec = ($total_waited_ms / 1000.0)
      if $current_content == $initial_content {
        return $"Command executed: ($command)\nNo new output detected after ($waited_sec) seconds\n---\n($current_content)\n---"
      } else {
        return $"Command executed: ($command)\nTimeout reached after ($waited_sec) seconds\n---\n($current_content)\n---"
      }
    }

    # Exponential back-off: 100ms, 150ms, 225ms, 337ms, 505ms, 757ms, 1000ms...
    if $delay_ms < 1000 {
      $delay_ms = ([$delay_ms * 1.5 1000] | math min) | into int
    }
  }
}