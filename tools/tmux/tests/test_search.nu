# Tests for tmux pane search and discovery tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mimic *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# find_pane_by_name tests
# =============================================================================

export def --env "test find_pane_by_name finds matching pane" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: list windows
    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0\n1"
    }

    # Mock: list panes for window 0
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|editor|nvim|1|/home/user/projects"
    }

    # Mock: list panes for window 1
    mimic register tmux {
      args: ['list-panes' '-t' 'dev:1' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|build|cargo|1|/home/user/projects\n1|test|npm|0|/home/user/frontend"
    }

    use ../search.nu find_pane_by_name
    let result = find_pane_by_name dev "build"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should find one pane"
    let found = $parsed | get 0
    assert ($found.title == "build") "Should have matching title"
    assert ($found.window == "1") "Should be in window 1"
    assert ($found.pane == "0") "Should be pane 0"
    assert ($found.target == "dev:1.0") "Should have correct target"
  }
}

export def --env "test find_pane_by_name case insensitive" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|Editor|nvim|1|/home/user"
    }

    use ../search.nu find_pane_by_name
    let result = find_pane_by_name dev "EDITOR"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should find pane case-insensitively"
  }
}

export def --env "test find_pane_by_name no match" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|other|zsh|1|/home/user"
    }

    use ../search.nu find_pane_by_name
    let result = find_pane_by_name dev "nonexistent"

    assert ($result | str contains "No pane named 'nonexistent'") "Should indicate no match"
  }
}

export def --env "test find_pane_by_name multiple matches" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0\n1"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|test|pytest|1|/home/user/tests"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:1' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|test|npm|0|/home/user/frontend"
    }

    use ../search.nu find_pane_by_name
    let result = find_pane_by_name dev "test"
    let parsed = $result | from json

    assert (($parsed | length) == 2) "Should find both matches"
  }
}

export def --env "test find_pane_by_name handles non-existent session" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'nonexistent' '-F' '#{window_index}']
      returns: "session not found"
      exit_code: 1
    }

    use ../search.nu find_pane_by_name
    let result = find_pane_by_name nonexistent "test"

    assert ($result | str contains "Error:") "Should return error"
    assert ($result | str contains "session 'nonexistent'") "Should mention session"
  }
}

# =============================================================================
# find_pane_by_context tests
# =============================================================================

export def --env "test find_pane_by_context finds by command" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|editor|nvim|1|/home/user\n1||cargo|0|/home/user/project"
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context dev "cargo"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should find by command"
    let found = $parsed | get 0
    assert ($found.command == "cargo") "Should match command"
  }
}

export def --env "test find_pane_by_context finds by directory name" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0||zsh|1|/home/user/projects"
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context dev "projects"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should find by directory name"
  }
}

export def --env "test find_pane_by_context finds by path substring" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0||zsh|1|/home/user/code/frontend"
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context dev "code"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should find by path substring"
  }
}

export def --env "test find_pane_by_context finds by title" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|my editor|nvim|1|/home/user"
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context dev "editor"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should find by title substring"
  }
}

export def --env "test find_pane_by_context case insensitive" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0|Frontend|zsh|1|/home/user"
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context dev "FRONTEND"
    let parsed = $result | from json

    assert (($parsed | length) == 1) "Should be case insensitive"
  }
}

export def --env "test find_pane_by_context no match" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'dev' '-F' '#{window_index}']
      returns: "0"
    }

    mimic register tmux {
      args: ['list-panes' '-t' 'dev:0' '-F' '#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}']
      returns: "0||zsh|1|/home/user"
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context dev "nonexistent"

    assert ($result | str contains "No pane matching context 'nonexistent'") "Should indicate no match"
  }
}

export def --env "test find_pane_by_context handles non-existent session" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['list-windows' '-t' 'nonexistent' '-F' '#{window_index}']
      returns: "session not found"
      exit_code: 1
    }

    use ../search.nu find_pane_by_context
    let result = find_pane_by_context nonexistent "test"

    assert ($result | str contains "Error:") "Should return error"
    assert ($result | str contains "session 'nonexistent'") "Should mention session"
  }
}
