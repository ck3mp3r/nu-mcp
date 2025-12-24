# Test wrappers for tmux tool tests
# These wrap external commands with nu-mimic for testing

use nu-mimic *

# Wrap tmux command for testing
export def --env --wrapped tmux [...args] {
  mimic call 'tmux' $args
}

# Wrap ps command for testing (used by process.nu)
export def --env --wrapped ps [...args] {
  mimic call 'ps' $args
}
