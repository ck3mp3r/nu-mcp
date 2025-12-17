# Mock wrapper functions for external commands used in c5t
# These check for MOCK_* environment variables for testing

# Mock query db command - intercepts the built-in query db
export def "query db" [
  sql: string
  --params (-p): list = []
] {
  # Pattern match on SQL to determine which mock to use
  # Check for specific SQL patterns first, then fall back to generic

  # Scratchpad check query
  if ($sql | str contains "SELECT id FROM note WHERE note_type = 'scratchpad'") {
    if "MOCK_query_db_CHECK_SCRATCHPAD" in $env {
      let mock_data = $env | get MOCK_query_db_CHECK_SCRATCHPAD
      if $mock_data.exit_code != 0 {
        error make {msg: $"SQLite error: ($mock_data.error)"}
      }
      return $mock_data.output
    }
  }

  # Empty items list scenario
  if ($sql | str contains "FROM todo_item") {
    if "MOCK_query_db_EMPTY_ITEMS" in $env {
      return []
    }
  }

  # Repository queries - check for last-accessed pattern first
  if ($sql | str contains "FROM repo") {
    # Last-accessed repo query (LIMIT 1 with ORDER BY last_accessed_at)
    if ($sql | str contains "ORDER BY last_accessed_at DESC LIMIT 1") {
      if "MOCK_query_db_REPO_LAST_ACCESSED" in $env {
        let mock_data = $env | get MOCK_query_db_REPO_LAST_ACCESSED
        if $mock_data.exit_code != 0 {
          error make {msg: $"SQLite error: ($mock_data.error)"}
        }
        return $mock_data.output
      }
    }
    # General repo queries
    if "MOCK_query_db_REPO" in $env {
      let mock_data = $env | get MOCK_query_db_REPO
      if $mock_data.exit_code != 0 {
        error make {msg: $"SQLite error: ($mock_data.error)"}
      }
      return $mock_data.output
    }
  }

  # Todo list queries
  if ($sql | str contains "FROM todo_list") {
    if "MOCK_query_db_TODO_LIST" in $env {
      let mock_data = $env | get MOCK_query_db_TODO_LIST
      if $mock_data.exit_code != 0 {
        error make {msg: $"SQLite error: ($mock_data.error)"}
      }
      return $mock_data.output
    }
  }

  # UPDATE queries (return empty list)
  if ($sql | str contains "UPDATE") {
    if "MOCK_query_db_UPDATE" in $env {
      let mock_data = $env | get MOCK_query_db_UPDATE
      if $mock_data.exit_code != 0 {
        error make {msg: $"SQLite error: ($mock_data.error)"}
      }
      return $mock_data.output
    }
    return []
  }

  # Generic mock for any other query
  if "MOCK_query_db" in $env {
    let mock_data = $env | get MOCK_query_db
    if $mock_data.exit_code != 0 {
      error make {msg: $"SQLite error: ($mock_data.error)"}
    }
    return $mock_data.output
  }

  # Default: empty list for INSERT/UPDATE/DELETE without RETURNING
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

# Mock git command for testing
export def --wrapped git [...rest] {
  let args = ($rest | str join "_" | str replace --all " " "_" | str replace --all "-" "_")
  let mock_var = $"MOCK_git_($args)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    if $mock_data.exit_code != 0 {
      error make {msg: $"Git error: ($mock_data.output)"}
    }
    $mock_data.output
  } else {
    # Fallback to real git
    ^git ...$rest
  }
}
