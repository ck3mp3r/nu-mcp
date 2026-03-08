# Context7 tool for nu-mcp - provides up-to-date library documentation
# Based on the Context7 MCP server: https://github.com/upstash/context7

# Import helper modules
use api.nu *
use formatters.nu *
use utils.nu *

# Default main command
def main [] {
  help main
}

# List available MCP tools
def "main list-tools" [] {
  [
    {
      name: "resolve_library_id"
      description: "Resolves a package/product name to a Context7-compatible library ID and returns a list of matching libraries.\n\nYou MUST call this function before 'get-library-docs' to obtain a valid Context7-compatible library ID UNLESS the user explicitly provides a library ID in the format '/org/project' or '/org/project/version' in their query.\n\nSelection Process:\n1. Analyze the query to understand what library/package the user is looking for\n2. Return the most relevant match based on:\n- Name similarity to the query (exact matches prioritized)\n- Description relevance to the query's intent\n- Documentation coverage (prioritize libraries with higher Code Snippet counts)\n- Source Reputation (consider libraries with High or Medium reputation more authoritative)\n- Benchmark Score (quality indicator, 100 is the highest score)\n- Trust Score (shown for older API responses, consider scores of 7-10 more authoritative)\n\nResponse Format:\n- Return the selected library ID in a clearly marked section\n- Provide a brief explanation for why this library was chosen\n- If multiple good matches exist, acknowledge this but proceed with the most relevant one\n- If no good matches exist, clearly state this and suggest query refinements\n\nFor ambiguous queries, request clarification before proceeding with a best-guess match."
      input_schema: {
        type: "object"
        properties: {
          libraryName: {
            type: "string"
            description: "Library name to search for and retrieve a Context7-compatible library ID."
          }
        }
        required: ["libraryName"]
      }
    }
    {
      name: "get_library_docs"
      description: "Fetches up-to-date documentation for a library. You must call 'resolve-library-id' first to obtain the exact Context7-compatible library ID required to use this tool, UNLESS the user explicitly provides a library ID in the format '/org/project' or '/org/project/version' in their query."
      input_schema: {
        type: "object"
        properties: {
          context7CompatibleLibraryID: {
            type: "string"
            description: "Exact Context7-compatible library ID (e.g., '/mongodb/docs', '/vercel/next.js', '/supabase/supabase', '/vercel/next.js/v14.3.0-canary.87') retrieved from 'resolve-library-id' or directly from user query in the format '/org/project' or '/org/project/version'."
          }
          topic: {
            type: "string"
            description: "Topic to focus documentation on (e.g., 'hooks', 'routing')."
          }
          tokens: {
            type: "number"
            description: "Maximum number of tokens of documentation to retrieve (default: 5000). Higher values provide more context but consume more tokens."
          }
        }
        required: ["context7CompatibleLibraryID"]
      }
    }
  ] | to json
}

# Call a specific tool with arguments
def "main call-tool" [
  tool_name: string # Name of the tool to call
  args: string = "{}" # JSON arguments for the tool
] {
  let parsed_args = $args | from json

  match $tool_name {
    "resolve_library_id" => {
      resolve_library_id ($parsed_args | get libraryName)
    }
    "get_library_docs" => {
      let library_id = $parsed_args | get context7CompatibleLibraryID
      let topic = $parsed_args | get --optional topic | default ""
      let tokens = $parsed_args | get --optional tokens | default 5000

      get_library_docs $library_id $topic $tokens
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}

# Resolve library name to Context7-compatible library ID
def resolve_library_id [
  library_name: string # Name of library to search for
] {
  # Get API key from environment if available
  let api_key = $env.CONTEXT7_API_KEY? | default ""

  # Search for libraries using the API
  # v2 API: libraryName is what we search, query is for ranking context
  let query = $"($library_name) library documentation"
  let search_result = search_libraries $library_name $query $api_key

  if not $search_result.success {
    return (format_error $search_result.error)
  }

  # Format and return the search results
  format_search_results $search_result.data
}

# Get library documentation using Context7-compatible library ID
def get_library_docs [
  library_id: string # Context7-compatible library ID
  topic: string = "" # Topic or query for documentation
  tokens: int = 5000 # Ignored in v2 API (kept for backward compatibility)
] {
  # Get API key from environment if available
  let api_key = $env.CONTEXT7_API_KEY? | default ""

  # v2 API: use topic as query parameter (same purpose, renamed)
  # If no topic provided, use generic query
  let query = if ($topic | is-empty) { "library documentation" } else { $topic }

  # Fetch documentation using the API
  let doc_result = fetch_library_documentation $library_id $query $api_key

  if not $doc_result.success {
    return (format_error $doc_result.error)
  }

  # Return the documentation
  $doc_result.data
}
