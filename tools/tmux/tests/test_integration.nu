# Integration tests for tmux workload operations
# These tests use REAL tmux sessions to verify behavior that cannot be mocked
#
# ISOLATION GUARANTEE:
# - Uses unique session name with timestamp: "mcp-integration-test-<timestamp>"
# - Checks for conflicts before starting
# - Always cleans up, even on failure
# - Will not interfere with user sessions

use std/assert

const TEST_SESSION_PREFIX = "mcp-integration-test"

# Generate unique session name with timestamp to avoid conflicts
def get-test-session-name [] {
  $"($TEST_SESSION_PREFIX)-(date now | format date '%Y%m%d-%H%M%S-%f')"
}

# Check if tmux is available
def check-tmux [] {
  try {
    ^tmux -V | complete | get exit_code | $in == 0
  } catch {
    false
  }
}

# Ensure no conflicting test sessions exist
def ensure-no-conflicts [] {
  let existing = try {
    ^tmux list-sessions -F '#{session_name}' | lines | where {|s| $s | str starts-with $TEST_SESSION_PREFIX }
  } catch {
    []
  }

  if ($existing | length) > 0 {
    error make {
      msg: $"Found existing test sessions: ($existing | str join ', '). Please clean up manually with: tmux kill-session -t <name>"
    }
  }
}

# Cleanup test session (always runs, even on failure)
def cleanup-test-session [session_name: string] {
  try {
    ^tmux kill-session -t $session_name
  } catch {
    # Session may not exist or already cleaned up
  }
}

# =============================================================================
# Integration test: Ownership rejection
# =============================================================================
# This test verifies the CRITICAL safety feature that prevents deletion of
# user-created panes. This cannot be tested with mocks because nu-mimic
# doesn't support exit_code parameter.
#
# What it tests:
# - User-created pane (no @mcp_tmux marker) is correctly identified as not owned
# - kill_pane correctly rejects deletion of user-created pane
# - Error message clearly explains the rejection
# =============================================================================

export def "test ownership rejection prevents killing user-created pane" [] {
  # Skip if tmux not available
  if not (check-tmux) {
    print "Skipping integration test - tmux not available"
    return
  }

  # Ensure clean state
  ensure-no-conflicts

  let session_name = get-test-session-name

  let test_result = try {
    # Create test session
    ^tmux new-session -d -s $session_name

    # Create a user pane (without MCP marker) by using tmux directly
    # This simulates what happens when a user manually creates a pane
    let user_pane = ^tmux split-window -t $"($session_name):" -h -dPF '#{pane_id}' | str trim

    # Verify the pane exists and has NO @mcp_tmux marker
    let has_marker = try {
      ^tmux show-options -pt $user_pane @mcp_tmux
      true
    } catch {
      false # Expected - option doesn't exist
    }
    assert ($has_marker == false) "User pane should not have @mcp_tmux marker"

    # Now try to kill it using our kill_pane function
    use ../workload.nu kill_pane
    let result = kill_pane $session_name --pane $user_pane --force | from json

    # Verify it was REJECTED
    assert ($result.success == false) "Should reject killing user-created pane"
    assert ($result.message | str contains "was not created by MCP") "Should explain MCP ownership requirement"

    # Verify the pane still exists (wasn't killed)
    let pane_still_exists = try {
      ^tmux list-panes -t $session_name -F '#{pane_id}' | lines | any {|p| $p == $user_pane }
    } catch {
      false
    }
    assert $pane_still_exists "User pane should still exist after rejection"

    print "✓ Integration test passed: Ownership rejection works correctly"
    {success: true}
  } catch {|err|
    print $"✗ Integration test failed: ($err)"
    {success: false error: $err}
  }

  # Always cleanup
  cleanup-test-session $session_name

  # Re-throw error if test failed
  if not $test_result.success {
    error make {msg: $"Integration test failed: ($test_result.error)"}
  }
}

# =============================================================================
# Integration test: MCP-created pane CAN be killed
# =============================================================================
# Verifies that panes created through our API (with @mcp_tmux marker) can be
# successfully deleted. This complements the ownership rejection test.
# =============================================================================

export def "test mcp-created pane can be killed successfully" [] {
  # Skip if tmux not available
  if not (check-tmux) {
    print "Skipping integration test - tmux not available"
    return
  }

  ensure-no-conflicts

  let session_name = get-test-session-name

  let test_result = try {
    # Create test session
    ^tmux new-session -d -s $session_name

    # Create an MCP pane using our split_pane function (which sets the marker)
    use ../workload.nu split_pane
    let result = split_pane $session_name "horizontal" | from json
    assert ($result.success == true) "split_pane should succeed"

    let mcp_pane = $result.pane_id

    # Verify the pane has the @mcp_tmux marker
    let marker_output = ^tmux show-options -pt $mcp_pane @mcp_tmux | str trim
    assert ($marker_output | str contains '@mcp_tmux') "MCP pane should have marker"

    # Now kill it using our kill_pane function
    use ../workload.nu kill_pane
    let kill_result = kill_pane $session_name --pane $mcp_pane --force | from json

    # Verify it was ACCEPTED and killed
    assert ($kill_result.success == true) "Should allow killing MCP-created pane"
    assert ($kill_result.message | str contains "Killed pane") "Should confirm deletion"

    # Verify the pane no longer exists
    let pane_still_exists = try {
      ^tmux list-panes -t $session_name -F '#{pane_id}' | lines | any {|p| $p == $mcp_pane }
    } catch {
      false
    }
    assert (not $pane_still_exists) "MCP pane should be deleted"

    print "✓ Integration test passed: MCP-created pane can be killed"
    {success: true}
  } catch {|err|
    print $"✗ Integration test failed: ($err)"
    {success: false error: $err}
  }

  # Always cleanup
  cleanup-test-session $session_name

  if not $test_result.success {
    error make {msg: $"Integration test failed: ($test_result.error)"}
  }
}

# =============================================================================
# Integration test: Round-trip marker verification
# =============================================================================
# Verifies that the @mcp_tmux marker is correctly set and can be read back
# for all resource types (panes, windows, sessions)
# =============================================================================

export def "test marker round-trip for all resource types" [] {
  if not (check-tmux) {
    print "Skipping integration test - tmux not available"
    return
  }

  ensure-no-conflicts

  let session_name = get-test-session-name

  let test_result = try {
    # Create test session
    ^tmux new-session -d -s $session_name

    # Test 1: Pane marker round-trip
    let pane_id = ^tmux split-window -t $"($session_name):" -h -dPF '#{pane_id}' | str trim
    ^tmux set-option -pt $pane_id @mcp_tmux 'true'
    let pane_marker = ^tmux show-options -pt $pane_id @mcp_tmux | str trim
    assert ($pane_marker | str contains '@mcp_tmux') "Pane marker should persist"

    # Test 2: Window marker round-trip  
    let window_info = ^tmux new-window -t $"($session_name):" -dPF '#{window_id}:#{window_index}' | str trim
    let window_idx = $window_info | split row ':' | last
    ^tmux set-option -wt $"($session_name):($window_idx)" @mcp_tmux 'true'
    let window_marker = ^tmux show-options -wt $"($session_name):($window_idx)" @mcp_tmux | str trim
    assert ($window_marker | str contains '@mcp_tmux') "Window marker should persist"

    # Test 3: Session marker round-trip
    ^tmux set-option -t $session_name @mcp_session_test 'true'
    let session_marker = ^tmux show-options -t $session_name @mcp_session_test | str trim
    assert ($session_marker | str contains '@mcp_session_test') "Session marker should persist"

    print "✓ Integration test passed: Markers persist correctly for all resource types"
    {success: true}
  } catch {|err|
    print $"✗ Integration test failed: ($err)"
    {success: false error: $err}
  }

  # Always cleanup
  cleanup-test-session $session_name

  if not $test_result.success {
    error make {msg: $"Integration test failed: ($test_result.error)"}
  }
}
