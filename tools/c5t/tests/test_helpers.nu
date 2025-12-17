# Test helpers for c5t tests
# Uses real SQLite databases in /tmp instead of mocks

use std/assert

# Create a temporary test database and return its path
# Usage: let test_env = (setup-test-db)
#        with-env $test_env { ... tests ... }
#        cleanup-test-db $test_env
export def setup-test-db [] {
  let test_id = (random chars --length 8)
  let test_dir = $"/tmp/c5t-test-($test_id)"
  mkdir $test_dir

  {
    XDG_DATA_HOME: $test_dir
    C5T_TEST_DIR: $test_dir
  }
}

# Clean up test database directory
export def cleanup-test-db [test_env: record] {
  let test_dir = $test_env.C5T_TEST_DIR
  if ($test_dir | path exists) {
    rm -rf $test_dir
  }
}

# Run a test with a fresh database
# Usage: with-test-db { ... test code ... }
export def with-test-db [test_fn: closure] {
  let test_env = (setup-test-db)
  try {
    with-env $test_env {
      do $test_fn
    }
  } catch {|err|
    cleanup-test-db $test_env
    error make {msg: $err.msg}
  }
  cleanup-test-db $test_env
}

# Create a test repo and return its ID
export def create-test-repo [remote: string = "github:test/repo"] {
  use ../storage.nu [ init-database ]

  # Initialize database first (creates schema)
  let db_path = init-database

  # Insert repo directly via the db
  let result = open $db_path | query db "INSERT INTO repo (remote, path) VALUES (?, ?) RETURNING id" -p [$remote "/tmp/test-repo"]

  if ($result | length) > 0 {
    $result.0.id
  } else {
    error make {msg: "Failed to create test repo"}
  }
}
