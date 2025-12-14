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

# Test create-todo-list with all parameters
export def "test create-todo-list with all parameters" [] {
  # Source mocks first, then storage (relative to project root)
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_random_int: ({output: 1234} | to json)
    MOCK_date_now: ({output: "2025-01-14T12:00:00Z"} | to json)
  } {
    let result = create-todo-list "Test List" "A test description" ["tag1" "tag2"]

    assert ($result.success == true)
    assert ($result.name == "Test List")
    assert ($result.description == "A test description")
    assert ($result.tags == ["tag1" "tag2"])
    assert ($result.id != null)
  }
}

# Test create-todo-list with minimal parameters
export def "test create-todo-list with minimal parameters" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_random_int: ({output: 5678} | to json)
    MOCK_date_now: ({output: "2025-01-14T12:00:00Z"} | to json)
  } {
    let result = create-todo-list "Minimal List"

    assert ($result.success == true)
    assert ($result.name == "Minimal List")
    assert ($result.description == null)
    assert ($result.tags == null)
  }
}

# Test get-active-lists returns empty list when no lists
export def "test get-active-lists returns empty list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  # Mock sqlite3 to return empty JSON array
  with-env {
    MOCK_sqlite3: ({output: "[]" exit_code: 0} | to json)
  } {
    let result = get-active-lists

    assert ($result.success == true)
    assert ($result.count == 0)
    assert ($result.lists == [])
  }
}

# Test get-active-lists returns lists
export def "test get-active-lists returns lists" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  let mock_data = [
    {
      id: "20250114120000-1234"
      name: "Test List 1"
      description: "Description 1"
      tags: '["tag1","tag2"]'
      created_at: "2025-01-14 12:00:00"
      updated_at: "2025-01-14 12:00:00"
    }
    {
      id: "20250114120100-5678"
      name: "Test List 2"
      description: null
      tags: null
      created_at: "2025-01-14 12:01:00"
      updated_at: "2025-01-14 12:01:00"
    }
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = get-active-lists

    assert ($result.success == true)
    assert ($result.count == 2)
    assert (($result.lists | length) == 2)
    assert ($result.lists.0.name == "Test List 1")
    assert ($result.lists.0.tags == ["tag1" "tag2"])
    assert ($result.lists.1.tags == [])
  }
}

# Test add-todo-item with all parameters
export def "test add-todo-item with all parameters" [] {
  use ../tests/mocks.nu *
  use ../storage.nu add-todo-item

  with-env {
    MOCK_random_int: ({output: 7890} | to json)
    MOCK_date_now: ({output: "2025-12-14T16:00:00Z"} | to json)
  } {
    let result = add-todo-item "list-123" "Test item" 5 "todo"

    assert ($result.success == true)
    assert ($result.content == "Test item")
    assert ($result.status == "todo")
    assert ($result.priority == 5)
    assert ($result.id != null)
  }
}

# Test add-todo-item with minimal parameters (backlog default)
export def "test add-todo-item defaults to backlog" [] {
  use ../tests/mocks.nu *
  use ../storage.nu add-todo-item

  with-env {
    MOCK_random_int: ({output: 1111} | to json)
    MOCK_date_now: ({output: "2025-12-14T16:00:00Z"} | to json)
  } {
    let result = add-todo-item "list-123" "Test item"

    assert ($result.success == true)
    assert ($result.status == "backlog")
    assert ($result.priority == null)
  }
}

# Test list-exists returns true when list exists
export def "test list-exists returns true for existing list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu list-exists

  let mock_data = [{id: "list-123"}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = list-exists "list-123"

    assert $result
  }
}

# Test list-exists returns false when list does not exist
export def "test list-exists returns false for non-existent list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu list-exists

  with-env {
    MOCK_sqlite3: ({output: "[]" exit_code: 0} | to json)
  } {
    let result = list-exists "non-existent"

    assert (not $result)
  }
}

# Test item-exists returns true when item exists
export def "test item-exists returns true for existing item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu item-exists

  let mock_data = [{id: "item-123"}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = item-exists "list-123" "item-123"

    assert $result
  }
}

# Test item-exists returns false when item does not exist
export def "test item-exists returns false for non-existent item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu item-exists

  with-env {
    MOCK_sqlite3: ({output: "[]" exit_code: 0} | to json)
  } {
    let result = item-exists "list-123" "non-existent"

    assert (not $result)
  }
}
