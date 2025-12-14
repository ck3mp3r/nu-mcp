# Mock wrapper functions for external commands used in c5t
# These check for MOCK_* environment variables for testing

# Mock run-query-db wrapper - returns output or simulates database operations
export def run-query-db [db_path: string sql: string params: list = []] {
  # Check for SQL-specific mocks first (for multiple calls with different responses)
  if ($sql | str contains "SELECT id FROM note WHERE note_type = 'scratchpad'") {
    if "MOCK_query_db_CHECK_SCRATCHPAD" in $env {
      let mock_data = $env | get MOCK_query_db_CHECK_SCRATCHPAD | from nuon
      if $mock_data.exit_code != 0 {
        error make {msg: $"SQLite error: ($mock_data.error)"}
      }
      return $mock_data.output
    }
  }

  # Mock for empty items list scenario
  if ($sql | str contains "FROM todo_item") {
    if "MOCK_query_db_EMPTY_ITEMS" in $env {
      # Return empty list (query db returns structured data, not strings)
      return []
    }
  }

  # Mock for todo list query
  if ($sql | str contains "FROM todo_list") {
    if "MOCK_query_db_TODO_LIST" in $env {
      let mock_data = $env | get MOCK_query_db_TODO_LIST | from nuon
      if $mock_data.exit_code != 0 {
        error make {msg: $"SQLite error: ($mock_data.error)"}
      }
      return $mock_data.output
    }
  }

  # Check for generic mock
  if "MOCK_query_db" in $env {
    let mock_data = $env | get MOCK_query_db | from nuon
    if $mock_data.exit_code != 0 {
      error make {msg: $"SQLite error: ($mock_data.error)"}
    }
    return $mock_data.output
  }

  # Default: success with empty list (for INSERT/UPDATE/DELETE)
  []
}

# Mock date now - returns a fixed timestamp for testing
export def "date now" [] {
  if "MOCK_date_now" in $env {
    let mock_data = $env | get "MOCK_date_now" | from json
    $mock_data.output | into datetime
  } else {
    # Fallback to actual date now
    ^date now
  }
}

# Mock random int - returns a fixed number for testing
export def "random int" [range: range] {
  # Check for mock environment variable
  # Try multiple possible formats since nushell represents ranges differently
  let mock_candidates = [
    $"MOCK_random_int_($range)"
    $"MOCK_random_int_1000..9999" # Common case
    "MOCK_random_int" # Generic fallback
  ]

  let mock_var = $mock_candidates | where {|var| $var in $env } | first

  if $mock_var != null {
    let mock_data = $env | get $mock_var | from json
    $mock_data.output
  } else {
    # Fallback: just return a default value
    1234
  }
}
