# Test wrappers for c67 tool tests
# These wrap HTTP client functions with nu-mimic for testing

use nu-mimic *

# Wrap http-get for testing
export def --env http-get [...args] {
  mimic call 'http-get' $args
}
