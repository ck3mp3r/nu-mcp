# Tests for storage.nu - database initialization and schema creation

use std/assert
use mocks.nu *

# Test get-db-path returns correct path
export def "test get-db-path returns correct path" [] {
  use ../storage.nu get-db-path

  let db_path = get-db-path

  assert ($db_path | str ends-with ".c5t/context.db")
}

# Test create-schema is called during init (integration-style test)
export def "test init-database calls create-schema" [] {
  # We test this by verifying init-database completes successfully
  # In a real integration test, we'd verify the schema was created
  use ../storage.nu init-database

  with-env {
    MOCK_query_db_CREATE: ({output: "" exit_code: 0})
  } {
    let db_path = init-database
    assert ($db_path != null)
  }
}

# Test create-todo-list with all parameters
export def "test create-todo-list with all parameters" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 42}]

  with-env {
    MOCK_query_db: ({output: $mock_response exit_code: 0})
  } {
    let result = create-todo-list "Test List" "A test description" ["tag1" "tag2"]

    assert ($result.success == true)
    assert ($result.name == "Test List")
    assert ($result.description == "A test description")
    assert ($result.tags == ["tag1" "tag2"])
    assert ($result.id == 42)
  }
}

# Test create-todo-list with minimal parameters
export def "test create-todo-list with minimal parameters" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 99}]

  with-env {
    MOCK_query_db: ({output: $mock_response exit_code: 0})
  } {
    let result = create-todo-list "Minimal List"

    assert ($result.success == true)
    assert ($result.name == "Minimal List")
    assert ($result.description == null)
    assert ($result.tags == null)
    assert ($result.id == 99)
  }
}

# Test get-active-lists returns empty list when no lists
export def "test get-active-lists returns empty list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  # Mock query db to return empty list (no rows)
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
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
      id: 1
      name: "Test List 1"
      description: "Description 1"
      tags: '["tag1","tag2"]'
      created_at: "2025-01-14 12:00:00"
      updated_at: "2025-01-14 12:00:00"
    }
    {
      id: 2
      name: "Test List 2"
      description: null
      tags: null
      created_at: "2025-01-14 12:01:00"
      updated_at: "2025-01-14 12:01:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
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

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 55}]

  with-env {
    MOCK_query_db: ({output: $mock_response exit_code: 0})
  } {
    let result = add-todo-item 123 "Test item" 5 "todo"

    assert ($result.success == true)
    assert ($result.content == "Test item")
    assert ($result.status == "todo")
    assert ($result.priority == 5)
    assert ($result.id == 55)
  }
}

# Test add-todo-item with minimal parameters (backlog default)
export def "test add-todo-item defaults to backlog" [] {
  use ../tests/mocks.nu *
  use ../storage.nu add-todo-item

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 66}]

  with-env {
    MOCK_query_db: ({output: $mock_response exit_code: 0})
  } {
    let result = add-todo-item 123 "Test item"

    assert ($result.success == true)
    assert ($result.status == "backlog")
    assert ($result.priority == null)
    assert ($result.id == 66)
  }
}

# Test list-exists returns true when list exists
export def "test list-exists returns true for existing list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu list-exists

  let mock_data = [{id: 123}]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = list-exists 123

    assert $result
  }
}

# Test list-exists returns false when list does not exist
export def "test list-exists returns false for non-existent list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu list-exists

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = list-exists 999

    assert (not $result)
  }
}

# Test item-exists returns true when item exists
export def "test item-exists returns true for existing item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu item-exists

  let mock_data = [{id: 123}]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = item-exists 123 123

    assert $result
  }
}

# Test item-exists returns false when item does not exist
export def "test item-exists returns false for non-existent item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu item-exists

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = item-exists 123 999

    assert (not $result)
  }
}

# Test update-todo-notes
export def "test update-todo-notes updates notes field" [] {
  use ../tests/mocks.nu *
  use ../storage.nu update-todo-notes

  let result = update-todo-notes 123 "Test notes content"

  assert ($result.success == true)
}

# Test generate-archive-note creates markdown
export def "test generate-archive-note generates markdown" [] {
  use ../storage.nu generate-archive-note

  let list = {
    name: "Test List"
    description: "Test description"
    notes: "Test notes"
  }

  let items = [
    {content: "Item 1" status: "done" completed_at: "2025-12-14"}
    {content: "Item 2" status: "cancelled" completed_at: null}
  ]

  let markdown = generate-archive-note $list $items

  assert ($markdown | str contains "# Test List")
  assert ($markdown | str contains "Test description")
  assert ($markdown | str contains "## Completed Items")
  assert ($markdown | str contains "Item 1")
  assert ($markdown | str contains "Item 2")
  assert ($markdown | str contains "## Progress Notes")
  assert ($markdown | str contains "Test notes")
  assert ($markdown | str contains "Auto-archived on")
}

# Test all-items-completed returns true when all done
export def "test all-items-completed returns true when all done" [] {
  use ../tests/mocks.nu *
  use ../storage.nu all-items-completed

  # Mock: no non-completed items
  let mock_data = [{count: 0}]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = all-items-completed 123

    assert $result
  }
}

# Test all-items-completed returns false when items pending
export def "test all-items-completed returns false when items pending" [] {
  use ../tests/mocks.nu *
  use ../storage.nu all-items-completed

  # Mock: 2 non-completed items
  let mock_data = [{count: 2}]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = all-items-completed 123

    assert (not $result)
  }
}

# Test create-note with all parameters
export def "test create-note with all parameters" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-note

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 77}]

  with-env {
    MOCK_query_db: ({output: $mock_response exit_code: 0})
  } {
    let result = create-note "Architecture Decision" "We decided to use Rust for the backend" ["architecture" "backend"]

    assert ($result.success == true)
    assert ($result.title == "Architecture Decision")
    assert ($result.tags == ["architecture" "backend"])
    assert ($result.id == 77)
  }
}

# Test create-note with minimal parameters (no tags)
export def "test create-note with minimal parameters" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-note

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 88}]

  with-env {
    MOCK_query_db: ({output: $mock_response exit_code: 0})
  } {
    let result = create-note "Quick Note" "Just a quick thought"

    assert ($result.success == true)
    assert ($result.title == "Quick Note")
    assert ($result.tags == null)
    assert ($result.id == 88)
  }
}

# Test get-notes returns empty list when no notes
export def "test get-notes returns empty list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-notes

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = get-notes

    assert ($result.success == true)
    assert ($result.count == 0)
    assert ($result.notes == [])
  }
}

# Test get-notes returns filtered notes by type
export def "test get-notes filters by note_type" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-notes

  let mock_data = [
    {
      id: 1
      title: "Manual Note"
      content: "Content"
      tags: null
      note_type: "manual"
      source_id: null
      created_at: "2025-01-14 16:30:00"
      updated_at: "2025-01-14 16:30:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = get-notes [] "manual"

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.note_type == "manual")
  }
}

# Test get-notes returns all note types
export def "test get-notes returns all note types" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-notes

  # Mock returns manual and archived notes
  let mock_data = [
    {
      id: 1
      title: "Manual Note"
      content: "Content"
      tags: "null"
      note_type: "manual"
      source_id: null
      created_at: "2025-01-14 16:30:00"
      updated_at: "2025-01-14 16:30:00"
    }
    {
      id: 2
      title: "Archived Todo"
      content: "Content"
      tags: "null"
      note_type: "archived_todo"
      source_id: 1
      created_at: "2025-01-14 16:00:00"
      updated_at: "2025-01-14 16:00:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    # Call without specifying note_type
    let result = get-notes

    assert ($result.success == true)
    assert ($result.count == 2)
  }
}

# Test get-note finds note
export def "test get-note finds note" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-note

  let mock_data = [
    {
      id: 123
      title: "Test Note"
      content: "Full content here"
      tags: '["tag1"]'
      note_type: "manual"
      source_id: null
      created_at: "2025-01-14 16:30:00"
      updated_at: "2025-01-14 16:30:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = get-note 123

    assert ($result.success == true)
    assert ($result.note.id == 123)
    assert ($result.note.title == "Test Note")
    assert ($result.note.tags == ["tag1"])
  }
}

# Test get-note returns error for non-existent ID
export def "test get-note returns error for non-existent" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-note

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = get-note 999

    assert ($result.success == false)
    assert ($result.error | str contains "Note not found")
  }
}

# --- Full-Text Search Tests (Milestone 7) ---

# Test search-notes with basic query returns results
export def "test search-notes basic query returns results" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  # Mock FTS5 search result
  let mock_data = [
    {
      id: 42
      title: "Database Design"
      content: "Notes about database architecture"
      tags: "[\"database\",\"architecture\"]"
      note_type: "manual"
      created_at: "2025-01-14 16:30:00"
      rank: -0.5
    }
    {
      id: 43
      title: "API Database"
      content: "Database schema for API"
      tags: "[\"api\",\"database\"]"
      note_type: "manual"
      created_at: "2025-01-14 17:00:00"
      rank: -0.3
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = search-notes "database"

    assert ($result.success == true)
    assert ($result.count == 2)
    assert ($result.notes.0.id == 42)
    assert ($result.notes.0.title == "Database Design")
    assert ($result.notes.0.tags == ["database" "architecture"])
    assert ($result.notes.1.id == 43)
    assert ($result.notes.1.tags == ["api" "database"])
  }
}

# Test search-notes respects limit parameter
export def "test search-notes respects limit parameter" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  # Mock returning only 1 result (simulating SQL LIMIT)
  let mock_data = [
    {
      id: 42
      title: "Database Design"
      content: "Notes about database architecture"
      tags: "[\"database\"]"
      note_type: "manual"
      created_at: "2025-01-14 16:30:00"
      rank: -0.5
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = search-notes "database" --limit 1

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.id == 42)
  }
}

# Test search-notes returns empty list when no matches
export def "test search-notes returns empty list when no matches" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = search-notes "nonexistent"

    assert ($result.success == true)
    assert ($result.count == 0)
    assert ($result.notes == [])
  }
}

# Test search-notes with boolean AND query
export def "test search-notes with boolean AND query" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  let mock_data = [
    {
      id: 42
      title: "Database API Design"
      content: "Notes about database API architecture"
      tags: "[\"database\",\"api\"]"
      note_type: "manual"
      created_at: "2025-01-14 16:30:00"
      rank: -0.5
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    # FTS5 boolean query
    let result = search-notes "database AND api"

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.id == 42)
  }
}

# --- Summary/Overview Tests (Task 17) ---

# Test get-summary returns expected structure
export def "test get-summary returns expected structure" [] {
  use ../storage.nu get-summary

  # NOTE: This is an integration-style test that uses the actual database
  # We're testing that the function returns the expected structure
  let result = get-summary

  # Verify structure exists
  assert ($result.success == true)
  assert ("summary" in $result)
  assert ("stats" in $result.summary)
  assert ("active_lists" in $result.summary)
  assert ("in_progress" in $result.summary)
  assert ("high_priority" in $result.summary)
  assert ("recently_completed" in $result.summary)

  # Verify stats fields
  assert ("active_lists" in $result.summary.stats)
  assert ("total_items" in $result.summary.stats)
  assert ("backlog_total" in $result.summary.stats)
  assert ("todo_total" in $result.summary.stats)
  assert ("in_progress_total" in $result.summary.stats)
}

# --- Delete Item Tests (CRUD) ---

# Test delete-item removes item from list
export def "test delete-item removes item successfully" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-item

  # Mock: item exists (first query returns row), then DELETE succeeds
  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = delete-item 1 42

    assert ($result.success == true)
  }
}

# Test delete-item returns error for non-existent item
export def "test delete-item returns error for non-existent item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-item

  # Mock: item doesn't exist (empty result from item-exists check)
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = delete-item 1 999

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# --- Delete List Tests (CRUD) ---

# Test delete-list removes empty list
export def "test delete-list removes empty list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  # Mock: list exists (returns row from TODO_LIST), has no items (count=0), DELETE succeeds
  # The generic MOCK_query_db handles the count query returning 0
  with-env {
    MOCK_query_db: ({output: [{count: 0}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 false

    assert ($result.success == true)
  }
}

# Test delete-list with force removes list and items
export def "test delete-list with force removes list and items" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  # Mock: list exists, force delete succeeds (no count check needed)
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 true

    assert ($result.success == true)
  }
}

# Test delete-list without force fails if list has items
export def "test delete-list without force fails if list has items" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  # Mock: list exists, but has 3 items (count query returns 3)
  with-env {
    MOCK_query_db: ({output: [{count: 3}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 false

    assert ($result.success == false)
    assert ($result.error | str contains "has items")
  }
}

# --- Delete Note Tests (CRUD) ---

# Test delete-note removes note
export def "test delete-note removes note successfully" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-note

  # Mock: note exists (SELECT returns row), DELETE succeeds
  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = delete-note 42

    assert ($result.success == true)
  }
}

# Test delete-note returns error for non-existent note
export def "test delete-note returns error for non-existent note" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-note

  # Mock: note doesn't exist (empty result)
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = delete-note 999

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# --- Edit Item Tests (CRUD) ---

# Test edit-item updates content
export def "test edit-item updates content successfully" [] {
  use ../tests/mocks.nu *
  use ../storage.nu edit-item

  # Mock: item exists (returns row), UPDATE succeeds
  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = edit-item 1 42 "Updated content"

    assert ($result.success == true)
  }
}

# Test edit-item returns error for non-existent item
export def "test edit-item returns error for non-existent item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu edit-item

  # Mock: item doesn't exist (empty result from item-exists check)
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = edit-item 1 999 "New content"

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test edit-item rejects empty content
export def "test edit-item rejects empty content" [] {
  use ../tests/mocks.nu *
  use ../storage.nu edit-item

  let result = edit-item 1 42 ""

  assert ($result.success == false)
  assert ($result.error | str contains "cannot be empty")
}

# --- Rename List Tests (CRUD) ---

# Test rename-list updates name
export def "test rename-list updates name successfully" [] {
  use ../tests/mocks.nu *
  use ../storage.nu rename-list

  # Mock: list exists (returns row), UPDATE succeeds
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = rename-list 1 "New Name"

    assert ($result.success == true)
  }
}

# Test rename-list updates name and description
export def "test rename-list updates name and description" [] {
  use ../tests/mocks.nu *
  use ../storage.nu rename-list

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = rename-list 1 "New Name" "New description"

    assert ($result.success == true)
  }
}

# Test rename-list returns error for non-existent list
export def "test rename-list returns error for non-existent list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu rename-list

  # Mock: list doesn't exist (empty result)
  with-env {
    MOCK_query_db_TODO_LIST: ({output: [] exit_code: 0})
  } {
    let result = rename-list 999 "New Name"

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test rename-list rejects empty name
export def "test rename-list rejects empty name" [] {
  use ../tests/mocks.nu *
  use ../storage.nu rename-list

  let result = rename-list 1 ""

  assert ($result.success == false)
  assert ($result.error | str contains "cannot be empty")
}

# --- Bulk Add Items Tests ---

# Test bulk-add-items adds multiple items
export def "test bulk-add-items adds multiple items" [] {
  use ../tests/mocks.nu *
  use ../storage.nu bulk-add-items

  # Mock: list exists, all inserts succeed
  with-env {
    MOCK_query_db: ({output: [{id: 1}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let items = [
      {content: "Item 1"}
      {content: "Item 2" priority: 1}
      {content: "Item 3" status: "todo"}
    ]
    let result = bulk-add-items 1 $items

    assert ($result.success == true)
    assert ($result.count == 3)
  }
}

# Test bulk-add-items returns error for non-existent list
export def "test bulk-add-items returns error for non-existent list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu bulk-add-items

  with-env {
    MOCK_query_db_TODO_LIST: ({output: [] exit_code: 0})
  } {
    let items = [{content: "Item 1"}]
    let result = bulk-add-items 999 $items

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test bulk-add-items rejects empty items list
export def "test bulk-add-items rejects empty items list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu bulk-add-items

  let result = bulk-add-items 1 []

  assert ($result.success == false)
  assert ($result.error | str contains "empty")
}

# --- Move Item Tests ---

# Test move-item moves item between lists
export def "test move-item moves item between lists" [] {
  use ../tests/mocks.nu *
  use ../storage.nu move-item

  # Mock: source item exists, target list exists, update succeeds
  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 2}] exit_code: 0})
  } {
    let result = move-item 1 42 2

    assert ($result.success == true)
  }
}

# Test move-item returns error for non-existent item
export def "test move-item returns error for non-existent item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu move-item

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = move-item 1 999 2

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# --- Export Data Tests ---

# Test export-data returns all data
export def "test export-data returns all data" [] {
  use ../tests/mocks.nu *
  use ../storage.nu export-data

  # Mock: return lists, items, and notes
  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1 name: "Test" status: "active"}] exit_code: 0})
  } {
    let result = export-data

    assert ($result.success == true)
    assert ("lists" in $result.data)
    assert ("items" in $result.data)
    assert ("notes" in $result.data)
    assert ("exported_at" in $result.data)
    assert ("version" in $result.data)
  }
}

# --- Bulk Update Status Tests ---

# Test bulk-update-status validates status
export def "test bulk-update-status validates status" [] {
  use ../tests/mocks.nu *
  use ../storage.nu bulk-update-status

  let result = bulk-update-status 1 [1 2] "invalid_status"

  assert ($result.success == false)
  assert ($result.error | str contains "Invalid status")
}

# --- Get List Tests ---

# Test get-list returns list metadata
export def "test get-list returns list metadata" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-list

  with-env {
    MOCK_query_db: ({output: [{id: 1 name: "Test List" description: "Test" status: "active" tags: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
  } {
    let result = get-list 1

    assert ($result.success == true)
    assert ($result.list.name == "Test List")
  }
}

# Test get-list returns error for non-existent list
export def "test get-list returns error for non-existent list" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-list

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
  } {
    let result = get-list 999

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}
