# Test wrappers for gh tool tests
# These wrap external commands with nu-mock for testing

use nu-mock *

# Wrap gh command for testing
export def --env --wrapped gh [...args] {
  mock call 'gh' $args
}

# Wrap git command for testing
export def --env --wrapped git [...args] {
  mock call 'git' $args
}
