# Test wrappers for c5t tool tests
# These wrap external commands with nu-mimic for testing

use nu-mimic *

# Wrap git command for testing
export def --env --wrapped git [...args] {
  mimic call 'git' $args
}

# Wrap cd command to do nothing (tests don't need actual directory changes)
export def --env cd [path?: any] {
  # Do nothing - mocks don't need real directory changes
}
