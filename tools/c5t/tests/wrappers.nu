# Test wrappers for c5t tool tests
# These wrap external commands with nu-mock for testing

use nu-mock *

# Wrap git command for testing
export def --env --wrapped git [...args] {
  mock call 'git' $args
}
