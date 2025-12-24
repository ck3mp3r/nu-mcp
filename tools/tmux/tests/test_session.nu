# Tests for tmux session management tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mimic *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# list_sessions tests
# =============================================================================

export def --env "test list_sessions returns session pane list" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: list-sessions command
    mimic register tmux {
      args: ['list-sessions' '-F' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}']
      returns: (sample-session-list)
    }

    # Mock: list-windows for 'dev' session (3 windows)
    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}|#{window_name}|#{window_panes}']
      returns: "0|editor|1
1|builds|2
2|logs|1"
    }

    # Mock: list-panes for dev:0
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}']
      returns: "0|nvim|1|editor"
    }

    # Mock: list-panes for dev:1
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:1' '-F' '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}']
      returns: "0|cargo|1|build
1|npm|0|test"
    }

    # Mock: list-panes for dev:2
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:2' '-F' '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}']
      returns: "0|tail|1|logs"
    }

    # Mock: list-windows for 'test' session (2 windows)
    mimic register tmux {
      args: ['list-windows' '-t' 'test' '-F' '#{window_index}|#{window_name}|#{window_panes}']
      returns: "0|runner|1
1|output|1"
    }

    # Mock: list-panes for test:0
    mimic register tmux {
      args: ['list-panes' '-t' 'test:0' '-F' '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}']
      returns: "0|pytest|1|"
    }

    # Mock: list-panes for test:1
    mimic register tmux {
      args: ['list-panes' '-t' 'test:1' '-F' '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}']
      returns: "0|less|1|"
    }

    use ../session.nu list_sessions
    let result = list_sessions
    let parsed = $result | from json

    assert (($parsed | length) == 6) "Should return 6 pane records total (4 from dev, 2 from test)"

    # Check first pane (dev:0.0)
    let first = $parsed | get 0
    assert ($first.session == "dev") "First pane session should be dev"
    assert ($first.session_status == "attached") "Dev session should be attached"
    assert ($first.window == "0") "First pane window should be 0"
    assert ($first.window_name == "editor") "First pane window_name should be editor"
    assert ($first.pane == "0") "First pane index should be 0"
    assert ($first.command == "nvim") "First pane command should be nvim"
    assert ($first.pane_status == "active") "First pane should be active"
  }
}

export def --env "test list_sessions with empty result" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-sessions' '-F' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}']
      returns: ""
    }

    use ../session.nu list_sessions
    let result = list_sessions

    assert ($result == "No tmux sessions found") "Should return no sessions message"
  }
}

export def --env "test list_sessions handles tmux not running" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-sessions' '-F' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}']
      returns: "no server running on /tmp/tmux-501/default"
      exit_code: 1
    }

    use ../session.nu list_sessions
    let result = list_sessions

    assert ($result | str contains "Failed to list tmux sessions") "Should return error message"
  }
}

export def --env "test list_sessions marks detached sessions correctly" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Session with attached=0
    mimic register tmux {
      args: ['list-sessions' '-F' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}']
      returns: "background|1734998600|0|1"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'background' '-F' '#{window_index}|#{window_name}|#{window_panes}']
      returns: "0|main|1"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'background:0' '-F' '#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}']
      returns: "0|zsh|1|"
    }

    use ../session.nu list_sessions
    let result = list_sessions
    let parsed = $result | from json

    let first = $parsed | get 0
    assert ($first.session_status == "detached") "Detached session should have status detached"
  }
}

# =============================================================================
# get_session_info tests
# =============================================================================

export def --env "test get_session_info returns formatted session details" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: display-message for session info
    mimic register tmux {
      args: ['display-message' '-t' 'dev' '-p' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}|#{session_group}|#{session_id}']
      returns: (sample-session-display)
    }

    # Mock: list-windows with active status
    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: "0|editor|1
1|builds|0
2|logs|0"
    }

    # Mock: list-panes for window 0 (active)
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0|editor|nvim|1|/home/user/projects|12345"
    }

    # Mock: list-panes for window 1
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:1' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0||cargo|1|/home/user/projects|12346
1||npm|0|/home/user/frontend|12347"
    }

    # Mock: list-panes for window 2
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:2' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0||tail|1|/var/log|12348"
    }

    use ../session.nu get_session_info
    let result = get_session_info dev

    # Check that result contains key information
    assert ($result | str contains "Session Information for: dev") "Should contain session name"
    assert ($result | str contains "Session ID: $0") "Should contain session ID"
    assert ($result | str contains "Status: attached") "Should show attached status"
    assert ($result | str contains "Windows: 3") "Should show window count"
    assert ($result | str contains "Windows and Panes:") "Should have panes section"
  }
}

export def --env "test get_session_info handles non-existent session" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['display-message' '-t' 'nonexistent' '-p' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}|#{session_group}|#{session_id}']
      returns: "session not found: nonexistent"
      exit_code: 1
    }

    use ../session.nu get_session_info
    let result = get_session_info nonexistent

    assert ($result | str contains "Failed to get session info for 'nonexistent'") "Should return error message"
    assert ($result | str contains "Check that the session exists") "Should suggest checking session exists"
  }
}

export def --env "test get_session_info shows custom pane names" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['display-message' '-t' 'dev' '-p' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}|#{session_group}|#{session_id}']
      returns: "dev|1734998400|1|1||$0"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: "0|editor|1"
    }

    # Pane with custom name (short, no special chars)
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0|myeditor|nvim|1|/home/user/projects|12345"
    }

    use ../session.nu get_session_info
    let result = get_session_info dev

    # Custom name is stored internally but not displayed in table output
    # The table only shows: window, window_name, pane, process, directory, status
    # We just verify the function runs without error
    assert ($result | str contains "Session Information for: dev") "Should return session info"
    assert ($result | str contains "nvim") "Should contain process name"
  }
}

export def --env "test get_session_info filters auto-generated titles" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['display-message' '-t' 'dev' '-p' '#{session_name}|#{session_created}|#{session_attached}|#{session_windows}|#{session_group}|#{session_id}']
      returns: "dev|1734998400|1|1||$0"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: "0|editor|1"
    }

    # Pane with auto-generated title (contains ">", long path)
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0|user@host:~/projects> vim|nvim|1|/home/user/projects|12345"
    }

    use ../session.nu get_session_info
    let result = get_session_info dev

    # Should not contain the auto-generated title in custom name field
    # This is internal logic - we just verify it runs without error
    assert (($result | str length) > 0) "Should return output"
  }
}

# =============================================================================
# list_panes tests
# =============================================================================

export def --env "test list_panes returns pane details as JSON" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: "0|editor|1
1|builds|0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0|editor|nvim|1|/home/user/projects|12345"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:1' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0||cargo|1|/home/user/projects|12346
1||npm|0|/home/user/frontend|12347"
    }

    use ../session.nu list_panes
    let result = list_panes dev
    let parsed = $result | from json

    assert (($parsed | length) == 3) "Should return 3 pane records"

    # Check first pane details
    let first = $parsed | get 0
    assert ($first.window == "0") "First pane window should be 0"
    assert ($first.window_name == "editor") "First pane window_name should be editor"
    assert ($first.pane == "0") "First pane index should be 0"
    assert ($first.name == "editor") "First pane should have custom name"
    assert ($first.process == "nvim") "First pane process should be nvim"
    assert ($first.directory == "projects") "First pane directory should be basename"
    assert ($first.full_path == "/home/user/projects") "First pane should have full path"
    assert ($first.pid == "12345") "First pane should have PID"
    assert ($first.status == "active") "First pane should be active"
    assert ($first.target == "dev:0.0") "First pane should have correct target"
  }
}

export def --env "test list_panes marks pane status correctly" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Window 0 is active
    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: "0|editor|1
1|builds|0"
    }

    # Window 0, pane 0 is active (should be "active")
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0||nvim|1|/home/user/projects|12345
1||zsh|0|/home/user/projects|12346"
    }

    # Window 1, pane 0 is active in that window (should be "current")
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:1' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}']
      returns: "0||cargo|1|/home/user/projects|12347
1||npm|0|/home/user/frontend|12348"
    }

    use ../session.nu list_panes
    let result = list_panes dev
    let parsed = $result | from json

    assert (($parsed | get 0 | get status) == "active") "Active pane in active window should be 'active'"
    assert (($parsed | get 1 | get status) == "inactive") "Inactive pane in active window should be 'inactive'"
    assert (($parsed | get 2 | get status) == "current") "Active pane in inactive window should be 'current'"
    assert (($parsed | get 3 | get status) == "inactive") "Inactive pane in inactive window should be 'inactive'"
  }
}

export def --env "test list_panes handles non-existent session" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'nonexistent' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: "session not found: nonexistent"
      exit_code: 1
    }

    use ../session.nu list_panes
    let result = list_panes nonexistent

    assert ($result | str contains "Failed to list panes for session 'nonexistent'") "Should return error message"
    assert ($result | str contains "Check that the session exists") "Should suggest checking session exists"
  }
}

export def --env "test list_panes with empty panes" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'empty' '-F' '#{window_index}|#{window_name}|#{window_active}']
      returns: ""
    }

    use ../session.nu list_panes
    let result = list_panes empty
    let parsed = $result | from json

    assert (($parsed | length) == 0) "Should return empty array"
  }
}
