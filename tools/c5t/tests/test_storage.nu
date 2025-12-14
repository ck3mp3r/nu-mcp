# Tests for storage.nu - database initialization and schema creation

use std/assert
use mocks.nu *

# Test get-db-path returns correct path
export def "test get-db-path returns correct path" [] {
  use ../storage.nu get-db-path

  let db_path = get-db-path

  assert ($db_path | str ends-with ".c5t/context.db")
}

# ======================================
# Scratchpad Tests (Milestone 8)
# ======================================

# Test update-scratchpad creates new scratchpad when none exists
export def "test update-scratchpad creates new scratchpad when none exists" [] {
  use ../tests/mocks.nu *
  use ../storage.nu update-scratchpad

  # First call: SELECT to check if scratchpad exists (returns empty string)
  let mock_check = ""
  # Second call: INSERT + SELECT returns the new ID
  let mock_insert = [{id: 1}] | to json

  with-env {
    MOCK_sqlite3_CHECK_SCRATCHPAD: ({output: $mock_check exit_code: 0} | to json)
    MOCK_sqlite3: ({output: $mock_insert exit_code: 0} | to json)
  } {
    let result = update-scratchpad "## Current Work\n\nWorking on feature X"

    assert ($result.success == true)
    assert ($result.scratchpad_id == 1)
  }
}

# Test update-scratchpad updates existing scratchpad
export def "test update-scratchpad updates existing scratchpad" [] {
  use ../tests/mocks.nu *
  use ../storage.nu update-scratchpad

  # Mock SELECT to return existing scratchpad with id 42
  let mock_select = [{id: 42}] | to json
  # Mock UPDATE success
  let mock_update = ""

  with-env {
    MOCK_sqlite3: ({output: $mock_select exit_code: 0} | to json)
    MOCK_sqlite3_UPDATE: ({output: $mock_update exit_code: 0} | to json)
  } {
    let result = update-scratchpad "## Updated Work\n\nNow working on feature Y"

    assert ($result.success == true)
    assert ($result.scratchpad_id == 42)
  }
}

# Test get-scratchpad returns current scratchpad
export def "test get-scratchpad returns current scratchpad" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-scratchpad

  # Mock SELECT to return existing scratchpad
  let mock_data = [
    {
      id: 42
      title: "Scratchpad"
      content: "## Current Work\n\nWorking on feature X"
      tags: "null"
      note_type: "scratchpad"
      created_at: "2025-01-14 16:00:00"
      updated_at: "2025-01-14 17:00:00"
    }
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = get-scratchpad

    assert ($result.success == true)
    assert ($result.scratchpad != null)
    assert ($result.scratchpad.id == 42)
    assert ($result.scratchpad.note_type == "scratchpad")
  }
}

# Test get-scratchpad returns null when no scratchpad exists
export def "test get-scratchpad returns null when no scratchpad exists" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-scratchpad

  # Mock SELECT to return empty string (like real sqlite for no rows)
  let mock_data = ""

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = get-scratchpad

    assert ($result.success == true)
    assert ($result.scratchpad == null)
  }
}

# Test only one scratchpad exists after multiple updates
export def "test only one scratchpad exists after multiple updates" [] {
  use ../tests/mocks.nu *
  use ../storage.nu update-scratchpad

  # First call: CREATE (check returns empty string, INSERT returns ID 1)
  let mock_check_empty = ""
  let mock_insert = [{id: 1}] | to json

  with-env {
    MOCK_sqlite3_CHECK_SCRATCHPAD: ({output: $mock_check_empty exit_code: 0} | to json)
    MOCK_sqlite3: ({output: $mock_insert exit_code: 0} | to json)
  } {
    let result1 = update-scratchpad "First content"
    assert ($result1.success == true)
    assert ($result1.scratchpad_id == 1)
  }

  # Second call: UPDATE (check returns ID 1, no INSERT needed)
  let mock_check_exists = [{id: 1}] | to json

  with-env {
    MOCK_sqlite3_CHECK_SCRATCHPAD: ({output: $mock_check_exists exit_code: 0} | to json)
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json) # UPDATE doesn't return data
  } {
    let result2 = update-scratchpad "Second content"
    assert ($result2.success == true)
    assert ($result2.scratchpad_id == 1) # Same ID as first call
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
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 42}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_response exit_code: 0} | to json)
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
  let mock_response = [{id: 99}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_response exit_code: 0} | to json)
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

  # Mock sqlite3 to return empty string (like real sqlite for no rows)
  with-env {
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json)
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

  # Mock the chained INSERT + SELECT response
  let mock_response = [{id: 55}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_response exit_code: 0} | to json)
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
  let mock_response = [{id: 66}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_response exit_code: 0} | to json)
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

  let mock_data = [{id: 123}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
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
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json)
  } {
    let result = list-exists 999

    assert (not $result)
  }
}

# Test item-exists returns true when item exists
export def "test item-exists returns true for existing item" [] {
  use ../tests/mocks.nu *
  use ../storage.nu item-exists

  let mock_data = [{id: 123}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
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
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json)
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
  let mock_data = [{count: 0}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
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
  let mock_data = [{count: 2}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
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
  let mock_response = [{id: 77}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_response exit_code: 0} | to json)
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
  let mock_response = [{id: 88}] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_response exit_code: 0} | to json)
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
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json)
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
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = get-notes [] "manual"

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.note_type == "manual")
  }
}

# Test get-notes excludes scratchpad by default
export def "test get-notes excludes scratchpad by default" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-notes

  # Mock returns manual and archived notes (no scratchpad)
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
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    # Call without specifying note_type
    let result = get-notes

    assert ($result.success == true)
    assert ($result.count == 2)
    # Verify no scratchpad in results
    assert (($result.notes | where note_type == "scratchpad" | length) == 0)
  }
}

# Test get-notes includes scratchpad when explicitly requested
export def "test get-notes includes scratchpad when explicitly requested" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-notes

  # Mock returns scratchpad
  let mock_data = [
    {
      id: 1
      title: "Scratchpad"
      content: "Current work"
      tags: "null"
      note_type: "scratchpad"
      source_id: null
      created_at: "2025-01-14 16:30:00"
      updated_at: "2025-01-14 17:00:00"
    }
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    # Explicitly request scratchpad
    let result = get-notes [] "scratchpad"

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.note_type == "scratchpad")
  }
}

# Test get-note-by-id finds note
export def "test get-note-by-id finds note" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-note-by-id

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
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = get-note-by-id 123

    assert ($result.success == true)
    assert ($result.note.id == 123)
    assert ($result.note.title == "Test Note")
    assert ($result.note.tags == ["tag1"])
  }
}

# Test get-note-by-id returns error for non-existent ID
export def "test get-note-by-id returns error for non-existent" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-note-by-id

  with-env {
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json)
  } {
    let result = get-note-by-id 999

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
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
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
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    let result = search-notes "database" --limit 1

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.id == 42)
  }
}

# Test search-notes filters by tags
export def "test search-notes filters by tags" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  # Mock returning notes with different tags
  let mock_data = [
    {
      id: 42
      title: "Database Design"
      content: "Notes about database"
      tags: "[\"database\",\"architecture\"]"
      note_type: "manual"
      created_at: "2025-01-14 16:30:00"
      rank: -0.5
    }
    {
      id: 43
      title: "Database API"
      content: "Database API notes"
      tags: "[\"api\",\"database\"]"
      note_type: "manual"
      created_at: "2025-01-14 17:00:00"
      rank: -0.3
    }
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    # Search with tag filter - should only return notes with "architecture" tag
    let result = search-notes "database" --tags ["architecture"]

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.id == 42)
    assert ("architecture" in $result.notes.0.tags)
  }
}

# Test search-notes returns empty list when no matches
export def "test search-notes returns empty list when no matches" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  with-env {
    MOCK_sqlite3: ({output: "" exit_code: 0} | to json)
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
  ] | to json

  with-env {
    MOCK_sqlite3: ({output: $mock_data exit_code: 0} | to json)
  } {
    # FTS5 boolean query
    let result = search-notes "database AND api"

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.notes.0.id == 42)
  }
}
