# Context7 API interaction module
# Handles API requests to Context7 service

use utils.nu [
  validate_search_response,
  validate_documentation_response,
  extract_http_status,
  get_search_error_message,
  get_docs_error_message
]

const CONTEXT7_API_BASE_URL = "https://context7.com/api"
const DEFAULT_TYPE = "txt"

# Generate headers for API requests
export def generate_headers [
  api_key: string = "" # API key for authentication
]: nothing -> record {
  let base_headers = {
    "Content-Type": "application/json"
    "User-Agent": "nu-mcp-context7/1.0"
  }

  if ($api_key | is-empty) {
    $base_headers
  } else {
    $base_headers | insert "X-Context7-API-Key" $api_key
  }
}

# Search for libraries matching the given query
export def search_libraries [
  query: string # Search query for libraries
  api_key: string = "" # Optional API key for authentication
]: nothing -> record {
  try {
    let url = $"($CONTEXT7_API_BASE_URL)/v1/search?query=($query | url encode)"
    let headers = generate_headers $api_key

    let response = http get --headers $headers $url

    # Validate response structure
    let validation = validate_search_response $response

    if not $validation.valid {
      return {
        success: false
        error: $validation.error
      }
    }

    {
      success: true
      data: $response
    }
  } catch {|error|
    # Extract HTTP status code from error message
    let status_code = extract_http_status $error.msg

    # Get appropriate error message based on status code
    let error_message = get_search_error_message $status_code $api_key

    # Use specific error message if available, otherwise use generic error
    let final_message = if ($error_message | is-empty) {
      $"Error searching libraries: ($error.msg)"
    } else {
      $error_message
    }

    {
      success: false
      error: $final_message
    }
  }
}

# Fetch documentation for a specific library
export def fetch_library_documentation [
  library_id: string # Context7-compatible library ID
  topic: string = "" # Optional topic to focus on
  tokens: int = 5000 # Maximum tokens to retrieve
  api_key: string = "" # Optional API key for authentication
]: nothing -> record {
  try {
    # Remove leading slash if present
    let clean_id = $library_id | str trim --left --char '/'

    # Build base URL with required parameters
    let base_url = $"($CONTEXT7_API_BASE_URL)/v1/($clean_id)?tokens=($tokens)&type=($DEFAULT_TYPE)"

    # Add optional topic parameter using pipeline idiom
    let url = if ($topic | is-empty) {
      $base_url
    } else {
      $"($base_url)&topic=($topic | url encode)"
    }

    let headers = generate_headers $api_key | insert "X-Context7-Source" "mcp-server"

    let response = http get --headers $headers $url

    # Check if response is empty or contains error indicators
    let is_invalid = (
      ($response | is-empty) or
      ($response == "No content available") or
      ($response == "No context data available")
    )

    if $is_invalid {
      return {
        success: false
        error: "Documentation not found or not finalized for this library. This might have happened because you used an invalid Context7-compatible library ID. To get a valid Context7-compatible library ID, use the 'resolve-library-id' with the package name you wish to retrieve documentation for."
      }
    }

    # Validate response structure
    let validation = validate_documentation_response $response

    if not $validation.valid {
      return {
        success: false
        error: $validation.error
      }
    }

    {
      success: true
      data: $response
    }
  } catch {|error|
    # Extract HTTP status code from error message
    let status_code = extract_http_status $error.msg

    # Get appropriate error message based on status code
    let error_message = get_docs_error_message $status_code $api_key

    # Use specific error message if available, otherwise use generic error
    let final_message = if ($error_message | is-empty) {
      $"Error fetching library documentation: ($error.msg)"
    } else {
      $error_message
    }

    {
      success: false
      error: $final_message
    }
  }
}
