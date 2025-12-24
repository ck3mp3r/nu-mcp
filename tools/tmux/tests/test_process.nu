# Tests for tmux process information tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mimic *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# get_pane_process tests
# =============================================================================

# Note: Tests for get_pane_process are limited because the function uses `^ps`
# which cannot be mocked. Tests focus on tmux integration and basic functionality.

export def --env "test get_pane_process with window and pane" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['display-message' '-t' 'dev:1.2' '-p' '#{pane_index}|#{pane_current_command}|#{pane_pid}|#{pane_current_path}|#{pane_width}x#{pane_height}|#{pane_active}']
      returns: "2|npm|$$|/home/user/frontend|150x50|0"
    }

    use ../process.nu get_pane_process
    let result = get_pane_process dev "1" "2"
    let parsed = $result | from json

    assert ($parsed.target == "dev:1.2") "Should have correct target with window and pane"
    assert ($parsed.pane_index == "2") "Should have correct pane index"
    assert ($parsed.current_command == "npm") "Should have npm command"
    assert ($parsed.size == "150x50") "Should have correct size"
    assert ($parsed.current_path == "/home/user/frontend") "Should have correct path"
  }
}

export def --env "test get_pane_process handles non-existent session" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['display-message' '-t' 'nonexistent' '-p' '#{pane_index}|#{pane_current_command}|#{pane_pid}|#{pane_current_path}|#{pane_width}x#{pane_height}|#{pane_active}']
      returns: "session not found"
      exit_code: 1
    }

    use ../process.nu get_pane_process
    let result = get_pane_process nonexistent

    assert ($result | str contains "Error:") "Should return error"
    assert ($result | str contains "Failed to get pane process info for 'nonexistent'") "Should mention session"
  }
}
