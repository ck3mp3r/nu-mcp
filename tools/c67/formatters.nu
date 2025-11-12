# Context7 output formatting utilities

# Format a single search result
export def format_search_result [
  result: record # Search result to format
]: nothing -> string {
  # Build base information (always present)
  let base_info = [
    $"- Title: ($result.title)"
    $"- Context7-compatible library ID: ($result.id)"
    $"- Description: ($result.description)"
  ]

  # Build optional fields using pipeline idiom
  let optional_fields = [
    # Add code snippets count if valid
    (
      if (($result.totalSnippets? | default (-1)) != -1) {
        [$"- Code Snippets: ($result.totalSnippets)"]
      } else {
        []
      }
    )
    # Add trust score if valid
    (
      if (($result.trustScore? | default (-1)) != -1) {
        [$"- Trust Score: ($result.trustScore)"]
      } else {
        []
      }
    )
    # Add versions if available
    (
      if (($result.versions? | default [] | length) > 0) {
        let versions_str = $result.versions | str join ", "
        [$"- Versions: ($versions_str)"]
      } else {
        []
      }
    )
  ] | flatten

  # Combine all fields and format
  $base_info | append $optional_fields | str join "\n"
}

# Format search results response
export def format_search_results [
  search_response: record # Response from search API
]: nothing -> string {
  # Assign to descriptive variable (best practice)
  let results = $search_response.results? | default []

  if ($results | is-empty) {
    return "No documentation libraries found matching your query."
  }

  # Format all results using pipeline
  let results_text = $results
  | each {|result| format_search_result $result }
  | str join "\n----------\n"

  let header = "Available Libraries (top matches):

Each result includes:
- Library ID: Context7-compatible identifier (format: /org/project)
- Name: Library or package name
- Description: Short summary
- Code Snippets: Number of available code examples
- Trust Score: Authority indicator
- Versions: List of versions if available. Use one of those versions if the user provides a version in their query. The format of the version is /org/project/version.

For best results, select libraries based on name match, trust score, snippet coverage, and relevance to your use case.

----------

"

  $"($header)($results_text)"
}

# Format error messages
export def format_error [
  error_msg: string # Error message to format
]: nothing -> string {
  $"❌ Error: ($error_msg)"
}
