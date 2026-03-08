# HTTP client wrapper functions for testability
# These wrappers allow mocking with nu-mimic in tests

# Wrapper for http get command
export def http-get [
  url: string
  headers: record
] {
  http get --headers $headers $url
}
