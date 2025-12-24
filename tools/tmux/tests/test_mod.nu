# Tests for tmux tool discovery and schemas

use std/assert
use nu-mimic *
use wrappers.nu *

# =============================================================================
# list-tools tests
# =============================================================================

export def --env "test list-tools returns valid json" [] {
  let result = nu tools/tmux/mod.nu list-tools
  let parsed = $result | from json

  assert (($parsed | length) > 0) "Should return at least one tool"
}

export def --env "test list-tools contains expected tools" [] {
  let result = nu tools/tmux/mod.nu list-tools
  let tools = $result | from json
  let names = $tools | get name

  assert ("list_sessions" in $names) "Should have list_sessions"
  assert ("send_and_capture" in $names) "Should have send_and_capture"
  assert ("send_command" in $names) "Should have send_command"
}
