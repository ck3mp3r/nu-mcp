# Context7 API interaction module
# Handles API requests to Context7 service

use http-client.nu [ http-get ]
use utils.nu [
  validate_search_response
  validate_documentation_response
  extract_http_status
  get_search_error_message
  get_docs_error_message
]

const CONTEXT7_API_BASE_URL = "https://context7.com/api"
const DEFAULT_TYPE = "txt"

# Generate headers for API requests
export def generate_headers [
  api_key: string = "" # API key for authentication
] {
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
  library_name: string # Library name to search for
  query: string # User's original question/task for intelligent ranking
  api_key: string = "" # Optional API key for authentication
] {
  try {
    # v2 endpoint - requires both libraryName and query parameters
    let url = $"($CONTEXT7_API_BASE_URL)/v2/libs/search?libraryName=($library_name | url encode)&query=($query | url encode)"
    let headers = generate_headers $api_key

    let response = http-get $url $headers

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
  query: string # User's question/task for intelligent ranking
  api_key: string = "" # Optional API key for authentication
] {
  try {
    # Remove leading slash if present
    let clean_id = $library_id | str trim --left --char '/'

    # v2 endpoint - libraryId as query param, query is required
    let url = $"($CONTEXT7_API_BASE_URL)/v2/context?libraryId=($clean_id | url encode)&query=($query | url encode)&type=($DEFAULT_TYPE)"

    let headers = generate_headers $api_key | insert "X-Context7-Source" "mcp-server"

    let response = http-get $url $headers

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
