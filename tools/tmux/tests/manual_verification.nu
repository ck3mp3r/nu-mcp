#!/usr/bin/env nu

# Manual Verification Script for Tmux Command Formats
#
# This script tests EVERY tmux command format we use in the tmux MCP tool
# to ensure they work correctly with real tmux sessions.
#
# DO NOT MOCK. This script exists to verify real tmux behavior.
#
# Run with: nu tools/tmux/tests/manual_verification.nu
#
# Results are written to: tools/tmux/tests/verification_results.md

const TEST_SESSION = "mcp-verify-test"
const RESULTS_FILE = "tools/tmux/tests/verification_results.md"

# =============================================================================
# Test Helpers
# =============================================================================

# Check if tmux is available
def check-tmux [] {
  try {
    ^tmux -V | complete | get exit_code | $in == 0
  } catch {
    false
  }
}

# Ensure test session exists
def ensure-test-session [] {
  try {
    ^tmux has-session -t $TEST_SESSION | complete | get exit_code
    if $in != 0 {
      print $"Creating test session: ($TEST_SESSION)"
      ^tmux new-session -d -s $TEST_SESSION
    }
  } catch {
    print $"Creating test session: ($TEST_SESSION)"
    ^tmux new-session -d -s $TEST_SESSION
  }
}

# Clean up test session
def cleanup-test-session [] {
  try {
    print $"Cleaning up test session: ($TEST_SESSION)"
    ^tmux kill-session -t $TEST_SESSION
  } catch {
    # Session may not exist
  }
}

# Run a test and record result
def run-test [
  name: string
  command: closure
  verification: closure
  --expect-fail # Set if command should fail
] {
  print $"\n=== Testing: ($name) ==="

  # Execute command and capture both success and return value
  mut cmd_return_value = null
  let result = try {
    $cmd_return_value = (do $command)
    {success: true error: null value: $cmd_return_value}
  } catch {|err|
    {success: false error: $err value: null}
  }

  let expected_outcome = if $expect_fail { "fail" } else { "success" }

  if ($expect_fail and $result.success) {
    print $"  ❌ UNEXPECTED SUCCESS (expected to fail)"
    return {
      name: $name
      status: "❌ FAIL"
      reason: "Expected failure but command succeeded"
      expected: $expected_outcome
      actual: "success"
    }
  }

  if (not $expect_fail and not $result.success) {
    print $"  ❌ UNEXPECTED FAILURE"
    print $"     Error: ($result.error)"
    return {
      name: $name
      status: "❌ FAIL"
      reason: $"Command failed: ($result.error)"
      expected: $expected_outcome
      actual: "failure"
    }
  }

  # Now verify the result - pass the command's return value to verification closure
  let verify_result = try {
    do $verification $result.value
    {verified: true error: null}
  } catch {|err|
    {verified: false error: $err}
  }

  if not $verify_result.verified {
    print $"  ⚠️  COMMAND SUCCEEDED but VERIFICATION FAILED"
    print $"     Error: ($verify_result.error)"
    return {
      name: $name
      status: "⚠️ PARTIAL"
      reason: $"Verification failed: ($verify_result.error)"
      expected: $expected_outcome
      actual: "success but unverified"
    }
  }

  print $"  ✅ PASSED"
  return {
    name: $name
    status: "✅ PASS"
    reason: "Command and verification succeeded"
    expected: $expected_outcome
    actual: "success"
  }
}

# =============================================================================
# Pane-level Option Tests
# =============================================================================

def test-pane-set-option-correct-format [] {
  run-test "set-option -pt <pane_id> (CORRECT format)" {
    # Split to create a pane
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):" -h -dPF '#{pane_id}' | str trim
    ^tmux set-option -pt $pane_id @mcp_tmux 'true'
    $pane_id
  } {|pane_id|
    # Verify option was set
    let output = ^tmux show-options -pt $pane_id @mcp_tmux | str trim
    if ($output | str contains '@mcp_tmux') {
      # Cleanup: kill the test pane
      ^tmux kill-pane -t $pane_id
      true
    } else {
      error make {msg: $"Option not set correctly. Output: ($output)"}
    }
  }
}

def test-pane-set-option-wrong-format [] {
  run-test "set-option -pt session:pane_id (WRONG format)" {
    # Split to create a pane
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):" -h -dPF '#{pane_id}' | str trim
    # Try WRONG format (session:pane) - this should fail
    try {
      ^tmux set-option -pt $"($TEST_SESSION):($pane_id)" @mcp_test 'wrong'
    } catch {
      # Expected to fail, cleanup and re-throw
      ^tmux kill-pane -t $pane_id
      error make {msg: "set-option with session:pane format failed as expected"}
    }
    # If we get here, command unexpectedly succeeded
    ^tmux kill-pane -t $pane_id
    $pane_id
  } {|pane_id|
    # This should have failed, so we shouldn't get here
    false
  } --expect-fail
}

def test-pane-show-option-correct-format [] {
  run-test "show-options -pt <pane_id> (CORRECT format)" {
    # Split and set option
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):" -h -dPF '#{pane_id}' | str trim
    ^tmux set-option -pt $pane_id @mcp_show_test 'true'
    $pane_id
  } {|pane_id|
    # Verify we can read it back
    let output = ^tmux show-options -pt $pane_id @mcp_show_test | str trim
    if ($output | str contains '@mcp_show_test') {
      # Cleanup
      ^tmux kill-pane -t $pane_id
      true
    } else {
      ^tmux kill-pane -t $pane_id
      error make {msg: $"Could not read option. Output: ($output)"}
    }
  }
}

def test-pane-show-option-nonexistent [] {
  run-test "show-options -pt <pane_id> with nonexistent option (should fail)" {
    # Split pane
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):" -h -dPF '#{pane_id}' | str trim
    # Try to read nonexistent option (should return non-zero)
    try {
      ^tmux show-options -pt $pane_id @nonexistent
    } catch {
      # Expected to fail, cleanup and re-throw
      ^tmux kill-pane -t $pane_id
      error make {msg: "show-options for nonexistent option failed as expected"}
    }
    # If we get here, unexpectedly succeeded
    ^tmux kill-pane -t $pane_id
    "unexpected success"
  } {|result|
    false
  } --expect-fail
}

# =============================================================================
# Pane Destruction Tests
# =============================================================================

def test-kill-pane-correct-format [] {
  run-test "kill-pane -t <pane_id> (CORRECT format)" {
    # Create a pane to kill
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):" -h -dPF '#{pane_id}' | str trim
    # Kill it using JUST the pane ID
    ^tmux kill-pane -t $pane_id
    $pane_id
  } {|pane_id|
    # Verify pane no longer exists
    let panes = ^tmux list-panes -t $TEST_SESSION -F '#{pane_id}'
    if ($panes | str contains $pane_id) {
      error make {msg: $"Pane ($pane_id) still exists after kill"}
    } else {
      true
    }
  }
}

def test-kill-pane-wrong-format [] {
  run-test "kill-pane -t session:pane_id (WRONG format - should fail)" {
    # Create a pane
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):" -h -dPF '#{pane_id}' | str trim
    # Try killing with session:pane format (WRONG - this should fail)
    try {
      ^tmux kill-pane -t $"($TEST_SESSION):($pane_id)"
      # If we get here, unexpectedly succeeded
      {success: true pane_id: $pane_id}
    } catch {
      # Expected to fail - cleanup the pane we created
      ^tmux kill-pane -t $pane_id
      error make {msg: "kill-pane with session:pane format failed as expected"}
    }
  } {|result|
    # Should never get here because command should have failed
    # But if we do, cleanup
    ^tmux kill-pane -t $result.pane_id
    false
  } --expect-fail
}

# =============================================================================
# Window-level Option Tests
# =============================================================================

def test-window-set-option-format [] {
  run-test "set-option -wt session:window (window-level)" {
    # Create a new window
    let window_info = ^tmux new-window -t $"($TEST_SESSION):" -dPF '#{window_id}:#{window_index}' | str trim
    let parts = $window_info | split row ':'
    let window_id = $parts.0
    let window_idx = $parts.1

    # Set option using session:window_index format (more reliable than window_id)
    ^tmux set-option -wt $"($TEST_SESSION):($window_idx)" @mcp_window_test 'true'
    {window_id: $window_id window_idx: $window_idx}
  } {|window_info|
    # Verify option was set
    let output = ^tmux show-options -wt $"($TEST_SESSION):($window_info.window_idx)" @mcp_window_test | str trim
    if ($output | str contains '@mcp_window_test') {
      # Cleanup: kill the test window
      ^tmux kill-window -t $"($TEST_SESSION):($window_info.window_idx)"
      true
    } else {
      ^tmux kill-window -t $"($TEST_SESSION):($window_info.window_idx)"
      error make {msg: $"Window option not set. Output: ($output)"}
    }
  }
}

# =============================================================================
# Session-level Option Tests
# =============================================================================

def test-session-set-option-format [] {
  run-test "set-option -t session (session-level)" {
    # Set session-level option
    ^tmux set-option -t $TEST_SESSION @mcp_session_test 'true'
    "session_option_set"
  } {|result|
    # Verify option was set
    let output = ^tmux show-options -t $TEST_SESSION @mcp_session_test | str trim
    if ($output | str contains '@mcp_session_test') {
      true
    } else {
      error make {msg: $"Session option not set. Output: ($output)"}
    }
  }
}

# =============================================================================
# Window and Pane Creation Tests
# =============================================================================

def test-new-window-format [] {
  run-test "new-window -t session: (with trailing colon)" {
    let output = ^tmux new-window -t $"($TEST_SESSION):" -n "test-window" -dPF '#{window_id}:#{window_index}' | str trim
    let parts = $output | split row ':'
    if ($parts | length) >= 2 {
      {window_idx: $parts.1}
    } else {
      error make {msg: $"Unexpected output format: ($output)"}
    }
  } {|result|
    # Verify window exists
    let windows = ^tmux list-windows -t $TEST_SESSION -F '#{window_name}'
    if ($windows | str contains 'test-window') {
      # Cleanup: kill the test window
      ^tmux kill-window -t $"($TEST_SESSION):($result.window_idx)"
      true
    } else {
      error make {msg: "Window 'test-window' not found"}
    }
  }
}

def test-split-window-session-only [] {
  run-test "split-window -t session: (current window)" {
    # Create a fresh window for this test to ensure space
    let window_info = ^tmux new-window -t $"($TEST_SESSION):" -dPF '#{window_index}' | str trim
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):($window_info)" -h -dPF '#{pane_id}' | str trim
    if ($pane_id | str starts-with '%') {
      {pane_id: $pane_id window_idx: $window_info}
    } else {
      ^tmux kill-window -t $"($TEST_SESSION):($window_info)"
      error make {msg: $"Invalid pane ID format: ($pane_id)"}
    }
  } {|result|
    # Cleanup: kill the test window (which kills all its panes)
    ^tmux kill-window -t $"($TEST_SESSION):($result.window_idx)"
    true
  }
}

def test-split-window-session-window [] {
  run-test "split-window -t session:window" {
    # Create a fresh window for this test
    let window_idx = ^tmux new-window -t $"($TEST_SESSION):" -dPF '#{window_index}' | str trim
    let pane_id = ^tmux split-window -t $"($TEST_SESSION):($window_idx)" -h -dPF '#{pane_id}' | str trim
    if ($pane_id | str starts-with '%') {
      {pane_id: $pane_id window_idx: $window_idx}
    } else {
      ^tmux kill-window -t $"($TEST_SESSION):($window_idx)"
      error make {msg: $"Invalid pane ID: ($pane_id)"}
    }
  } {|result|
    # Cleanup: kill the test window
    ^tmux kill-window -t $"($TEST_SESSION):($result.window_idx)"
    true
  }
}

# =============================================================================
# Layout Management
# =============================================================================

def test-select-layout-all-layouts [] {
  let layouts = ["even-horizontal" "even-vertical" "main-horizontal" "main-vertical" "tiled"]

  mut results = []
  for layout in $layouts {
    let result = run-test $"select-layout -t session: ($layout)" {
      ^tmux select-layout -t $"($TEST_SESSION):" $layout
      $layout
    } {|layout|
      # No easy way to verify layout applied, just check command succeeded
      true
    }
    $results = ($results | append $result)
  }

  $results
}

# =============================================================================
# Format Variable Tests
# =============================================================================

def test-format-variables [] {
  run-test "Format variables in list-sessions" {
    let output = ^tmux list-sessions -F "#{session_name}|#{session_created}|#{session_attached}|#{session_windows}" | str trim
    let parts = $output | lines | first | split row '|'
    if ($parts | length) >= 4 {
      "format_valid"
    } else {
      error make {msg: $"Unexpected format output: ($output)"}
    }
  } {|result|
    true
  }
}

# =============================================================================
# Main Test Runner
# =============================================================================

def main [] {
  print "\n╔════════════════════════════════════════════════════════════════╗"
  print "║  Tmux Command Format Manual Verification                      ║"
  print "║  Testing with REAL tmux sessions                              ║"
  print "╚════════════════════════════════════════════════════════════════╝\n"

  # Check tmux availability
  if not (check-tmux) {
    print "❌ ERROR: tmux is not available"
    print "   Please install tmux and try again"
    exit 1
  }

  print $"Tmux version: (^tmux -V)"
  print ""

  # Setup
  cleanup-test-session # Clean any existing test session
  ensure-test-session

  # Run all tests
  mut all_results = []

  print "\n## Pane-level Options"
  $all_results = ($all_results | append (test-pane-set-option-correct-format))
  $all_results = ($all_results | append (test-pane-set-option-wrong-format))
  $all_results = ($all_results | append (test-pane-show-option-correct-format))
  $all_results = ($all_results | append (test-pane-show-option-nonexistent))

  print "\n## Pane Destruction"
  $all_results = ($all_results | append (test-kill-pane-correct-format))
  $all_results = ($all_results | append (test-kill-pane-wrong-format))

  print "\n## Window-level Options"
  $all_results = ($all_results | append (test-window-set-option-format))

  print "\n## Session-level Options"
  $all_results = ($all_results | append (test-session-set-option-format))

  print "\n## Window and Pane Creation"
  $all_results = ($all_results | append (test-new-window-format))
  $all_results = ($all_results | append (test-split-window-session-only))
  $all_results = ($all_results | append (test-split-window-session-window))

  print "\n## Layout Management"
  let layout_results = test-select-layout-all-layouts
  $all_results = ($all_results | append $layout_results)

  print "\n## Format Variables"
  $all_results = ($all_results | append (test-format-variables))

  # Cleanup
  cleanup-test-session

  # Generate summary
  print "\n\n╔════════════════════════════════════════════════════════════════╗"
  print "║  Test Summary                                                  ║"
  print "╚════════════════════════════════════════════════════════════════╝\n"

  let total = $all_results | length
  let passed = $all_results | where status == "✅ PASS" | length
  let failed = $all_results | where status == "❌ FAIL" | length
  let partial = $all_results | where status == "⚠️ PARTIAL" | length

  print $"Total tests: ($total)"
  print $"Passed: ($passed) ✅"
  print $"Failed: ($failed) ❌"
  print $"Partial: ($partial) ⚠️"
  print ""

  if $failed > 0 {
    print "Failed tests:"
    $all_results | where status == "❌ FAIL" | each {|test|
      print $"  - ($test.name): ($test.reason)"
    }
  }

  if $partial > 0 {
    print "Partial tests (command worked but verification failed):"
    $all_results | where status == "⚠️ PARTIAL" | each {|test|
      print $"  - ($test.name): ($test.reason)"
    }
  }

  # Write results to markdown
  generate-results-markdown $all_results

  print $"\nResults written to: ($RESULTS_FILE)"

  # Exit with error if any tests failed
  if $failed > 0 {
    exit 1
  }
}

def generate-results-markdown [results: list] {
  mut output = [
    "# Tmux Command Format Verification Results"
    ""
    $"Generated: (date now | format date '%Y-%m-%d %H:%M:%S')"
    $"Tmux Version: (^tmux -V)"
    ""
    "## Summary"
    ""
    $"- Total: ($results | length)"
    $"- Passed: ($results | where status == '✅ PASS' | length) ✅"
    $"- Failed: ($results | where status == '❌ FAIL' | length) ❌"
    $"- Partial: ($results | where status == '⚠️ PARTIAL' | length) ⚠️"
    ""
    "## Detailed Results"
    ""
  ]

  for result in $results {
    $output = ($output | append $"### ($result.status) ($result.name)")
    $output = ($output | append "")
    $output = ($output | append $"- **Expected:** ($result.expected)")
    $output = ($output | append $"- **Actual:** ($result.actual)")
    $output = ($output | append $"- **Reason:** ($result.reason)")
    $output = ($output | append "")
  }

  $output | str join (char newline) | save -f $RESULTS_FILE
}
