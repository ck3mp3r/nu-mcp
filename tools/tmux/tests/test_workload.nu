# Tests for tmux window and pane management tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mimic *
use test_helpers.nu *
use wrappers.nu *

# =============================================================================
# create_window tests
# =============================================================================

export def --env "test create_window with session only" [] {
  with-mimic {
    # Mock: tmux version check
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: new-window command (session only, returns window info)
    mimic register tmux {
      args: ['new-window' '-t' 'dev:' '-dPF' '#{window_id}:#{window_index}']
      returns: "@1:2"
    }

    use ../workload.nu create_window
    let result = create_window dev

    assert ($result | str contains "window_id") "Should return window_id"
    assert ($result | str contains "window_index") "Should return window_index"
    assert ($result | str contains "success") "Should indicate success"
  }
}

export def --env "test create_window with window name" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: new-window with name
    mimic register tmux {
      args: ['new-window' '-t' 'dev:' '-n' 'mywindow' '-dPF' '#{window_id}:#{window_index}']
      returns: "@2:3"
    }

    use ../workload.nu create_window
    let result = create_window dev --name "mywindow"

    assert ($result | str contains "mywindow") "Should mention window name"
    assert ($result | str contains "success") "Should indicate success"
  }
}

export def --env "test create_window with working directory" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: new-window with directory
    mimic register tmux {
      args: ['new-window' '-t' 'dev:' '-c' '/tmp' '-dPF' '#{window_id}:#{window_index}']
      returns: "@3:4"
    }

    use ../workload.nu create_window
    let result = create_window dev --directory "/tmp"

    assert ($result | str contains "success") "Should indicate success"
  }
}

# TODO: Fix error mocking - nu-mimic has issues with exit_code mocking
# export def --env "test create_window handles non-existent session" [] {
#   with-mimic {
#     mimic register tmux {
#       args: ['-V']
#       returns: "tmux 3.3a"
#     }
#
#     # Mock: tmux error for non-existent session
#     mimic register tmux {
#       args: ['new-window' '-t' 'nonexistent:' '-dPF' '#{window_id}:#{window_index}']
#       returns: "session not found: nonexistent"
#       exit_code: 1
#     }
#
#     use ../workload.nu create_window
#     let result = create_window nonexistent
#
#     assert ($result | str contains "error" or $result | str contains "not found") "Should indicate error"
#   }
# }

# =============================================================================
# split_pane tests
# =============================================================================

export def --env "test split_pane horizontal split" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: split-window horizontal
    mimic register tmux {
      args: ['split-window' '-t' 'dev:' '-h' '-dPF' '#{pane_id}']
      returns: "%4"
    }

    use ../workload.nu split_pane
    let result = split_pane dev "horizontal"

    assert ($result | str contains "pane_id") "Should return pane_id"
    assert ($result | str contains "success") "Should indicate success"
  }
}

export def --env "test split_pane vertical split" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: split-window vertical
    mimic register tmux {
      args: ['split-window' '-t' 'dev:' '-v' '-dPF' '#{pane_id}']
      returns: "%5"
    }

    use ../workload.nu split_pane
    let result = split_pane dev "vertical"

    assert ($result | str contains "pane_id") "Should return pane_id"
    assert ($result | str contains "success") "Should indicate success"
  }
}

export def --env "test split_pane with working directory" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    # Mock: split-window with directory
    mimic register tmux {
      args: ['split-window' '-t' 'dev:' '-h' '-c' '/tmp' '-dPF' '#{pane_id}']
      returns: "%6"
    }

    use ../workload.nu split_pane
    let result = split_pane dev "horizontal" --directory "/tmp"

    assert ($result | str contains "success") "Should indicate success"
  }
}

# TODO: Fix error mocking - nu-mimic has issues with exit_code mocking
# export def --env "test split_pane handles non-existent session" [] {
#   with-mimic {
#     mimic register tmux {
#       args: ['-V']
#       returns: "tmux 3.3a"
#     }
#
#     # Mock: tmux error for non-existent session
#     mimic register tmux {
#       args: ['split-window' '-t' 'nonexistent:' '-h' '-dPF' '#{pane_id}']
#       returns: "session not found: nonexistent"
#       exit_code: 1
#     }
#
#     use ../workload.nu split_pane
#     let result = split_pane nonexistent "horizontal"
#
#     assert ($result | str contains "error" or $result | str contains "not found") "Should indicate error"
#   }
# }
