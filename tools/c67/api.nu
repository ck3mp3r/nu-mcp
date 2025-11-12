# Context7 API interaction module
# Handles API requests to Context7 service

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

    {
      success: true
      data: $response
    }
  } catch {|error|
    # Assign error to descriptive variable (best practice)
    let err_msg = $error.msg

    # Parse error to provide better messages
    let error_message = if ($err_msg | str contains "429") {
      if ($api_key | is-empty) {
        "Rate limited due to too many requests. You can create a free API key at https://context7.com/dashboard for higher rate limits."
      } else {
        "Rate limited due to too many requests. Please try again later."
      }
    } else if ($err_msg | str contains "401") {
      $"Unauthorized. Please check your API key. The API key you provided is: ($api_key). API keys should start with 'ctx7sk'"
    } else if ($err_msg | str contains "404") {
      "No libraries found matching your query."
    } else {
      $"Error searching libraries: ($err_msg)"
    }

    {
      success: false
      error: $error_message
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

    # Check if response is empty or invalid
    let is_invalid = (
      ($response | is-empty) or
      ($response == "No content available") or
      ($response == "No context data available")
    )

    if $is_invalid {
      {
        success: false
        error: "Documentation not found or not finalized for this library. This might have happened because you used an invalid Context7-compatible library ID. To get a valid Context7-compatible library ID, use the 'resolve-library-id' with the package name you wish to retrieve documentation for."
      }
    } else {
      {
        success: true
        data: $response
      }
    }
  } catch {|error|
    # Assign error to descriptive variable (best practice)
    let err_msg = $error.msg

    # Parse error to provide better messages
    let error_message = if ($err_msg | str contains "429") {
      if ($api_key | is-empty) {
        "Rate limited due to too many requests. You can create a free API key at https://context7.com/dashboard for higher rate limits."
      } else {
        "Rate limited due to too many requests. Please try again later."
      }
    } else if ($err_msg | str contains "404") {
      "The library you are trying to access does not exist. Please try with a different library ID."
    } else if ($err_msg | str contains "401") {
      $"Unauthorized. Please check your API key. The API key you provided is: ($api_key). API keys should start with 'ctx7sk'"
    } else {
      $"Error fetching library documentation: ($err_msg)"
    }

    {
      success: false
      error: $error_message
    }
  }
}
