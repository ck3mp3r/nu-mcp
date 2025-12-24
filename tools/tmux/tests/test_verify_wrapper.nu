# Simple verification test to ensure wrapper pattern works

use std/assert
use nu-mimic *
use wrappers.nu *

export def --env "test tmux wrapper with spread args" [] {
  with-mimic {
    # Register a simple mock
    mimic register tmux {
      args: ['list-sessions' '-F' 'test']
      returns: "session1"
    }

    # Call tmux with spread operator
    let result = tmux list-sessions -F test

    assert ($result == "session1") "Should return mocked value"
  }
}

export def --env "test tmux wrapper version check" [] {
  with-mimic {
    mimic register tmux {
      args: ['-V']
      returns: "tmux 3.3a"
    }

    let result = tmux -V

    assert ($result == "tmux 3.3a") "Should return mocked version"
  }
}
