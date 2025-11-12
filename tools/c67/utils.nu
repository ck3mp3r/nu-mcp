# Context7 utility functions and helpers

# Validate library ID format
export def validate_library_id [
  library_id: string # Library ID to validate
]: nothing -> record {
  # Context7 IDs should be in format: /org/project or /org/project/version
  if not ($library_id | str starts-with "/") {
    return {
      valid: false
      error: "Library ID must start with '/'"
    }
  }

  # Parse ID components
  let parts = $library_id | str trim --left --char '/' | split row "/"

  if ($parts | length) < 2 {
    return {
      valid: false
      error: "Library ID must have at least org and project: /org/project"
    }
  }

  {
    valid: true
    id: $library_id
  }
}

# URL encode a string for query parameters
export def url_encode []: string -> string {
  # Assign input to descriptive variable (best practice)
  let text = $in

  # Use pipeline idiom for sequential transformations
  $text
  | str replace --all " " "%20"
  | str replace --all "!" "%21"
  | str replace --all "\"" "%22"
  | str replace --all "#" "%23"
  | str replace --all "$" "%24"
  | str replace --all "&" "%26"
  | str replace --all "'" "%27"
  | str replace --all "(" "%28"
  | str replace --all ")" "%29"
  | str replace --all "*" "%2A"
  | str replace --all "+" "%2B"
  | str replace --all "," "%2C"
  | str replace --all "/" "%2F"
  | str replace --all ":" "%3A"
  | str replace --all ";" "%3B"
  | str replace --all "=" "%3D"
  | str replace --all "?" "%3F"
  | str replace --all "@" "%40"
  | str replace --all "[" "%5B"
  | str replace --all "]" "%5D"
}

# Extract error message from HTTP error
export def extract_http_error [
  error: record # Error record to parse
]: nothing -> string {
  if "status" in $error {
    match $error.status {
      429 => "Rate limit exceeded"
      401 => "Unauthorized - invalid API key"
      404 => "Not found"
      500 => "Internal server error"
      _ => $"HTTP error: ($error.status)"
    }
  } else {
    $"Error: ($error.msg? | default 'Unknown error')"
  }
}

# Parse tokens parameter ensuring minimum value
export def parse_tokens [
  tokens: any # Token value to parse (can be int, string, or other)
]: nothing -> int {
  let value = match ($tokens | describe) {
    "int" => $tokens
    "string" => ($tokens | into int)
    _ => 5000
  }

  # Ensure minimum of 1000 tokens
  if $value < 1000 { 1000 } else { $value }
}
