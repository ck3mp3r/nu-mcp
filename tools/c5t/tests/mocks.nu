# Mock wrapper functions for external commands used in c5t
# These check for MOCK_* environment variables for testing

# Mock sqlite3 command - returns output or simulates database operations
export def --wrapped sqlite3 [...rest] {
  let db_path = $rest.0
  let sql = if ($rest | length) > 1 { $rest.1 } else { "" }

  # Create a normalized key for the mock
  let sql_hash = $sql | str replace --all " " "_" | str replace --all "\n" "_" | str substring 0..50
  let mock_var = $"MOCK_sqlite3_($sql_hash)"

  if $mock_var in $env {
    let mock_data = $env | get $mock_var | from json
    if $mock_data.exit_code != 0 {
      error make {msg: $"SQLite error: ($mock_data.output)"}
    }
    $mock_data.output
  } else {
    # Default: success with empty output (for CREATE TABLE, etc.)
    ""
  }
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
export def "random int" [...args] {
  # Accept either two integers or a range
  let range_str = if ($args | length) == 2 {
    $"($args.0)..($args.1)"
  } else {
    # It's a range, convert to string
    $args.0 | into string
  }

  let mock_var = $"MOCK_random_int_($range_str)"

  if $mock_var in $env {
    let mock_data = $env | get $mock_var | from json
    $mock_data.output
  } else {
    # Fallback: just return a default value
    1234
  }
}
