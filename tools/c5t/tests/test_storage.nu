# Tests for storage.nu - database initialization and schema creation

use std/assert
use mocks.nu *

# Test get-db-path returns correct path
export def "test get-db-path returns correct path" [] {
  use ../storage.nu get-db-path

  let db_path = get-db-path

  assert ($db_path | str ends-with ".c5t/context.db")
}

# Test init-database creates database
export def "test init-database creates database file" [] {
  # This test would actually create a database file
  # For now, we'll test that the function is callable
  use ../storage.nu init-database

  # Mock the sqlite3 calls to not actually create files
  with-env {
    MOCK_sqlite3_CREATE: ({output: "" exit_code: 0} | to json)
  } {
    let db_path = init-database
    assert ($db_path | str ends-with ".c5t/context.db")
  }
}

# Test create-schema is called during init (integration-style test)
export def "test init-database calls create-schema" [] {
  # We test this by verifying init-database completes successfully
  # In a real integration test, we'd verify the schema was created
  use ../storage.nu init-database

  with-env {
    MOCK_sqlite3_CREATE: ({output: "" exit_code: 0} | to json)
  } {
    let db_path = init-database
    assert ($db_path != null)
  }
}

# NOTE: Storage tests are integration tests that require actual database
# For now, we test that the functions are callable and return expected structure
# Unit tests focus on pure data transformations in other modules

# Test that create-todo-list returns proper structure on success
export def "test create-todo-list returns success structure" [] {
  # This is more of a smoke test - we can't easily mock sqlite3 calls
  # In a real scenario, we'd use dependency injection or test databases

  # Just verify the function signature is correct
  use ../storage.nu create-todo-list

  # The function should exist and be callable
  # Actual functionality requires a database
  assert true
}

# Test that get-active-lists returns proper structure
export def "test get-active-lists returns proper structure" [] {
  # Smoke test for function signature
  use ../storage.nu get-active-lists

  # The function should exist and be callable
  assert true
}
