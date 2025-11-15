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

# Extract HTTP status code from error message
export def extract_http_status [
  error_msg: string # Error message to parse
]: nothing -> int {
  # Try to extract HTTP status codes from common error message patterns
  match $error_msg {
    $msg if ($msg | str contains "400") => 400
    $msg if ($msg | str contains "401") => 401
    $msg if ($msg | str contains "403") => 403
    $msg if ($msg | str contains "404") => 404
    $msg if ($msg | str contains "429") => 429
    $msg if ($msg | str contains "500") => 500
    $msg if ($msg | str contains "502") => 502
    $msg if ($msg | str contains "503") => 503
    $msg if ($msg | str contains "504") => 504
    $msg if (($msg | str contains "Network failure") or ($msg | str contains "connection")) => 0
    _ => -1
  }
}

# Generate error message for library search based on HTTP status
export def get_search_error_message [
  status_code: int # HTTP status code
  api_key: string = "" # API key for context
]: nothing -> string {
  match $status_code {
    400 => "Bad request. The library name query parameter may be invalid or malformed."
    401 => $"Unauthorized. Please check your API key. The API key you provided is: ($api_key). API keys should start with 'ctx7sk'"
    403 => "Forbidden. Your API key may not have permission to access this resource."
    404 => "No libraries found matching your query."
    429 => {
      if ($api_key | is-empty) {
        "Rate limited due to too many requests. You can create a free API key at https://context7.com/dashboard for higher rate limits."
      } else {
        "Rate limited due to too many requests. Please try again later."
      }
    }
    500 => "Internal server error on Context7 API. Please try again later."
    502 => "Bad gateway. Context7 API may be temporarily unavailable."
    503 => "Service unavailable. Context7 API is temporarily down for maintenance."
    504 => "Gateway timeout. The request took too long. Please try again."
    0 => "Network error. Please check your internet connection and try again."
    _ => ""
  }
}

# Generate error message for documentation fetch based on HTTP status
export def get_docs_error_message [
  status_code: int # HTTP status code
  api_key: string = "" # API key for context
]: nothing -> string {
  match $status_code {
    400 => "Bad request. The library ID, topic, or tokens parameter may be invalid."
    401 => $"Unauthorized. Please check your API key. The API key you provided is: ($api_key). API keys should start with 'ctx7sk'"
    403 => "Forbidden. Your API key may not have permission to access this library's documentation."
    404 => "The library you are trying to access does not exist. Please verify the library ID using 'resolve-library-id'."
    429 => {
      if ($api_key | is-empty) {
        "Rate limited due to too many requests. You can create a free API key at https://context7.com/dashboard for higher rate limits."
      } else {
        "Rate limited due to too many requests. Please try again later."
      }
    }
    500 => "Internal server error on Context7 API. Please try again later."
    502 => "Bad gateway. Context7 API may be temporarily unavailable."
    503 => "Service unavailable. Context7 API is temporarily down for maintenance."
    504 => "Gateway timeout. The documentation request took too long. Try reducing the tokens parameter."
    0 => "Network error. Please check your internet connection and try again."
    _ => ""
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

# Validate search response structure
export def validate_search_response [
  response: any # Response from search API to validate
]: nothing -> record {
  # Check if response is a record
  let response_type = $response | describe
  if not ($response_type | str contains "record") {
    return {
      valid: false
      error: $"Invalid response format: expected a record, got ($response_type)"
    }
  }

  # Check if results field exists and is not empty
  try {
    let results = $response.results?

    # If results doesn't exist or is null, it's invalid
    if ($results == null) {
      return {
        valid: false
        error: "Invalid response: missing 'results' field"
      }
    }

    # Check if results is a list
    let results_type = $results | describe
    if not ($results_type | str contains "list") {
      return {
        valid: false
        error: $"Invalid response: 'results' must be a list, got ($results_type)"
      }
    }

    # Validate each result has required fields (id and title are minimum)
    let invalid_results = $results | where {|result|
      ($result.id? == null) or ($result.title? == null)
    }

    if ($invalid_results | length) > 0 {
      return {
        valid: false
        error: $"Invalid response: ($invalid_results | length) results are missing required fields (id, title)"
      }
    }

    {
      valid: true
    }
  } catch {|err|
    {
      valid: false
      error: $"Error validating search response: ($err.msg)"
    }
  }
}

# Validate documentation response
export def validate_documentation_response [
  response: any # Response from documentation API to validate
]: nothing -> record {
  # Check if response is a string
  let response_type = $response | describe
  if ($response_type != "string") {
    return {
      valid: false
      error: $"Invalid response format: expected documentation as string, got ($response_type)"
    }
  }

  # Check if response is empty
  if ($response | str length) == 0 {
    return {
      valid: false
      error: "Documentation response is empty"
    }
  }

  {
    valid: true
  }
}
