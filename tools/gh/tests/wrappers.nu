# Test wrappers for gh tool tests
# These wrap external commands with nu-mimic for testing

use nu-mimic *

# Wrap gh command for testing
export def --env --wrapped gh [...args] {
  mimic call 'gh' $args
}

# Wrap git command for testing
export def --env --wrapped git [...args] {
  mimic call 'git' $args
}
