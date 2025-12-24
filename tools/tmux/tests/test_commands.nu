# Tests for tmux command execution tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mimic *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# send_command tests
# =============================================================================

export def --env "test send_command sends command to pane" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: send-keys command
    mimic register tmux {
      args: ['send-keys' '-t' 'dev:0.0' 'ls -la' 'Enter']
      returns: ""
    }

    use ../commands.nu send_command
    let result = send_command dev "ls -la" "0" "0"

    assert ($result | str contains "Command sent to dev:0.0") "Should confirm command sent"
    assert ($result | str contains "ls -la") "Should show the command"
  }
}

export def --env "test send_command with session only" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['send-keys' '-t' 'dev' 'echo test' 'Enter']
      returns: ""
    }

    use ../commands.nu send_command
    let result = send_command dev "echo test"

    assert ($result | str contains "Command sent to dev") "Should send to session"
  }
}

export def --env "test send_command handles non-existent session" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['send-keys' '-t' 'nonexistent' 'test' 'Enter']
      returns: "session not found"
      exit_code: 1
    }

    use ../commands.nu send_command
    let result = send_command nonexistent "test"

    assert ($result | str contains "Error:") "Should return error"
    assert ($result | str contains "session 'nonexistent'") "Should mention session name"
  }
}

# =============================================================================
# capture_pane tests
# =============================================================================

export def --env "test capture_pane captures pane content" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['capture-pane' '-t' 'dev:0.0' '-p']
      returns: (sample-captured-content)
    }

    use ../commands.nu capture_pane
    let result = capture_pane dev "0" "0"

    assert ($result | str contains "Pane content from dev:0.0:") "Should show pane target"
    assert ($result | str contains "user@host:~/projects") "Should contain captured content"
    assert ($result | str contains "Cargo.toml") "Should contain file listing"
  }
}

export def --env "test capture_pane with window and pane" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['capture-pane' '-t' 'dev:1.0' '-p']
      returns: "line1\nline2\nline3"
    }

    use ../commands.nu capture_pane
    let result = capture_pane dev "1" "0"

    assert ($result | str contains "Pane content from dev:1.0:") "Should show target"
    assert ($result | str contains "line1") "Should contain content"
  }
}

export def --env "test capture_pane handles non-existent session" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    mimic register tmux {
      args: ['capture-pane' '-t' 'nonexistent' '-p']
      returns: "can't find session nonexistent"
      exit_code: 1
    }

    use ../commands.nu capture_pane
    let result = capture_pane nonexistent

    assert ($result | str contains "Error:") "Should return error"
    assert ($result | str contains "session/pane 'nonexistent'") "Should mention session"
  }
}

# =============================================================================
# send_and_capture tests
# =============================================================================

export def --env "test send_and_capture executes command and captures output" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Initial capture (empty prompt)
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$"
    }

    # Send command
    mimic register tmux {
      args: ['send-keys' '-t' 'dev' 'echo hello' 'Enter']
      returns: ""
    }

    # Subsequent capture (with output)
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$ echo hello\nhello\nuser@host:~$"
    }

    use ../commands.nu send_and_capture
    let result = send_and_capture dev "echo hello"

    assert ($result | str contains "Command executed: echo hello") "Should show command"
    assert ($result | str contains "hello") "Should contain output"
  }
}

export def --env "test send_and_capture with no new output" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Initial capture
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$"
    }

    # Send command
    mimic register tmux {
      args: ['send-keys' '-t' 'dev' 'sleep 100' 'Enter']
      returns: ""
    }

    # Subsequent captures (no change - command still running)
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$"
    }

    use ../commands.nu send_and_capture
    let result = send_and_capture dev "sleep 100"

    assert ($result | str contains "Command executed: sleep 100") "Should show command"
    assert ($result | str contains "No new output detected") "Should indicate no output"
  }
}

export def --env "test send_and_capture handles initial capture error" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Initial capture fails
    mimic register tmux {
      args: ['capture-pane' '-t' 'nonexistent' '-p']
      returns: "session not found"
      exit_code: 1
    }

    use ../commands.nu send_and_capture
    let result = send_and_capture nonexistent "test"

    assert ($result | str contains "Error:") "Should return error"
  }
}

export def --env "test send_and_capture handles send command error" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Initial capture succeeds
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$"
    }

    # Send command fails
    mimic register tmux {
      args: ['send-keys' '-t' 'dev' 'test' 'Enter']
      returns: "pane not found"
      exit_code: 1
    }

    use ../commands.nu send_and_capture
    let result = send_and_capture dev "test"

    assert ($result | str contains "Error:") "Should return error"
  }
}

export def --env "test send_and_capture with window and pane" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Initial capture
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev:0.1' '-p']
      returns: "user@host:~$"
    }

    # Send command
    mimic register tmux {
      args: ['send-keys' '-t' 'dev:0.1' 'echo test' 'Enter']
      returns: ""
    }

    # Subsequent capture with output
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev:0.1' '-p']
      returns: "user@host:~$ echo test\ntest\nuser@host:~$"
    }

    use ../commands.nu send_and_capture
    let result = send_and_capture dev "echo test" "0" "1"

    assert ($result | str contains "Command executed: echo test") "Should show command"
    assert ($result | str contains "test") "Should contain output"
  }
}

export def --env "test send_and_capture with custom wait time" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Initial capture
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$"
    }

    # Send command
    mimic register tmux {
      args: ['send-keys' '-t' 'dev' 'echo test' 'Enter']
      returns: ""
    }

    # Subsequent captures
    mimic register tmux {
      args: ['capture-pane' '-t' 'dev' '-p']
      returns: "user@host:~$ echo test\ntest\nuser@host:~$"
    }

    use ../commands.nu send_and_capture
    let result = send_and_capture dev "echo test"

    assert ($result | str contains "Command executed: echo test") "Should execute"
    assert ($result | str contains "test") "Should capture output"
  }
}
