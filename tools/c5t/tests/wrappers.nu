# Test wrappers for c5t tool tests
# These wrap external commands with nu-mock for testing

use nu-mock *

# Wrap git command for testing
export def --env --wrapped git [...args] {
  mock call 'git' $args
}

# Wrap cd command to do nothing (tests don't need actual directory changes)
export def --env cd [path?: any] {
  # Do nothing - mocks don't need real directory changes
}
