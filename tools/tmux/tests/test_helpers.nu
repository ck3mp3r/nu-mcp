# Test helper functions for tmux tool tests

# Sample session list for list_sessions
# Format string: #{session_name}|#{session_created}|#{session_attached}|#{session_windows}
export def sample-session-list [] {
  "dev|1734998400|1|3
test|1734998500|0|2"
}

# Sample window list
# Format: #{window_index}|#{window_name}|#{window_panes}
export def sample-window-list [] {
  "0|editor|1
1|builds|4
2|logs|2"
}

# Sample pane list
# Format: #{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_title}
export def sample-pane-list [] {
  "0|nvim|1|editor
1|cargo|0|build
2|npm|0|test"
}

# Sample session info for get_session_info
# Format: #{session_name}|#{session_created}|#{session_attached}|#{session_windows}|#{session_group}|#{session_id}
export def sample-session-display [] {
  "dev|1734998400|1|3||$0"
}

# Sample pane info with full details for get_session_info/list_panes
# Format: #{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_active}|#{pane_current_path}|#{pane_pid}
export def sample-pane-detailed [] {
  "0|editor|nvim|1|/home/user/projects|12345
1||cargo|0|/home/user/projects|12346
2|test|npm|0|/home/user/frontend|12347"
}

# Sample pane process info
# Format: #{pane_index}|#{pane_current_command}|#{pane_pid}|#{pane_current_path}|#{pane_width}x#{pane_height}|#{pane_active}
export def sample-pane-process [] {
  "0|nvim|12345|/home/user/projects|120x40|1"
}

# Sample captured pane content
export def sample-captured-content [] {
  "user@host:~/projects$ ls -la
total 24
-rw-r--r--  1 user  staff  123 Dec 24 09:00 Cargo.toml
drwxr-xr-x  4 user  staff  128 Dec 24 08:00 src
user@host:~/projects$"
}

# Setup common tmux mocks (version check, etc.)
export def --env setup-tmux-mocks [] {
  use nu-mimic *
  use wrappers.nu *

  # Mock tmux version check (required by check_tmux)
  mimic register tmux {
    args: ['-V']
    returns: "tmux 3.3a"
  }
}
