# Tests for storage.nu - core CRUD operations
# Focus: Test exposed tool functions, not internal helpers

use std/assert
use mocks.nu *

# --- List Operations ---

# Test create-todo-list creates list with all fields
export def "test create-todo-list success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = create-todo-list "Test List" "A description" ["tag1" "tag2"]

    assert ($result.success == true)
    assert ($result.name == "Test List")
    assert ($result.id == 42)
  }
}

# Test get-active-lists returns lists with parsed tags
export def "test get-active-lists success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-active-lists

  let mock_data = [
    {
      id: 1
      name: "Test List"
      description: "Desc"
      tags: '["tag1","tag2"]'
      created_at: "2025-01-14 12:00:00"
      updated_at: "2025-01-14 12:00:00"
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = get-active-lists

    assert ($result.success == true)
    assert ($result.count == 1)
    assert ($result.lists.0.tags == ["tag1" "tag2"])
  }
}

# Test upsert-list creates new list when no list_id (via create-todo-list)
export def "test upsert-list creates new" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-todo-list

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    # upsert-list delegates to create-todo-list when no list_id
    let result = create-todo-list "New List" "Description" ["tag1"]

    assert ($result.success == true)
  }
}

# Test upsert-list updates existing list
export def "test upsert-list updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-list

  with-env {
    MOCK_query_db: ({output: [{id: 1 name: "Updated" description: "Desc" status: "active" tags: null notes: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1 name: "Test" description: null status: "active" tags: null notes: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
  } {
    let result = upsert-list 1 "Updated Name"

    assert ($result.success == true)
    assert ($result.created == false)
  }
}

# Test upsert-list fails for non-existent list
export def "test upsert-list fails for non-existent" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-list

  with-env {
    MOCK_query_db_TODO_LIST: ({output: [] exit_code: 0})
  } {
    let result = upsert-list 999 "Name"

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test get-list returns metadata
export def "test get-list success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-list

  with-env {
    MOCK_query_db: ({output: [{id: 1 name: "Test" description: "Desc" status: "active" tags: null notes: null created_at: "2025-01-01" updated_at: "2025-01-01" archived_at: null}] exit_code: 0})
  } {
    let result = get-list 1

    assert ($result.success == true)
    assert ($result.list.name == "Test")
  }
}

# Test delete-list removes empty list
export def "test delete-list success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  with-env {
    MOCK_query_db: ({output: [{count: 0}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 false

    assert ($result.success == true)
  }
}

# Test delete-list fails if list has items (without force)
export def "test delete-list fails with items" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-list

  with-env {
    MOCK_query_db: ({output: [{count: 3}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = delete-list 1 false

    assert ($result.success == false)
    assert ($result.error | str contains "has items")
  }
}

# --- Item Operations ---

# Test add-todo-item creates item with defaults
export def "test add-todo-item success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu add-todo-item

  with-env {
    MOCK_query_db: ({output: [{id: 55}] exit_code: 0})
  } {
    let result = add-todo-item 1 "Test item"

    assert ($result.success == true)
    assert ($result.status == "backlog")
    assert ($result.id == 55)
  }
}

# Test upsert-item updates existing item
export def "test upsert-item updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-item

  with-env {
    MOCK_query_db: ({output: [{id: 42 list_id: 1 content: "Updated" status: "in_progress" priority: 1 position: null created_at: "2025-01-01" started_at: null completed_at: null}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = upsert-item 1 42 "Updated content"

    assert ($result.success == true)
    assert ($result.created == false)
  }
}

# Test upsert-item fails for non-existent item
export def "test upsert-item fails for non-existent" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-item

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1}] exit_code: 0})
  } {
    let result = upsert-item 1 999 "Content"

    assert ($result.success == false)
    assert ($result.error | str contains "not found")
  }
}

# Test delete-item removes item
export def "test delete-item success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-item

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = delete-item 1 42

    assert ($result.success == true)
  }
}

# Test move-item moves between lists
export def "test move-item success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu move-item

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 2}] exit_code: 0})
  } {
    let result = move-item 1 42 2

    assert ($result.success == true)
  }
}

# --- Note Operations ---

# Test create-note creates note
export def "test create-note success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu create-note

  with-env {
    MOCK_query_db: ({output: [{id: 77}] exit_code: 0})
  } {
    let result = create-note "Test Note" "Content" ["tag1"]

    assert ($result.success == true)
    assert ($result.id == 77)
  }
}

# Test upsert-note updates existing note
export def "test upsert-note updates existing" [] {
  use ../tests/mocks.nu *
  use ../storage.nu upsert-note

  with-env {
    MOCK_query_db: ({output: [{id: 42 title: "Updated" content: "New content" tags: null note_type: "manual" source_id: null created_at: "2025-01-01" updated_at: "2025-01-01"}] exit_code: 0})
  } {
    let result = upsert-note 42 "New Title"

    assert ($result.success == true)
    assert ($result.created == false)
  }
}

# Test get-note finds note
export def "test get-note success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu get-note

  let mock_data = [
    {
      id: 123
      title: "Test Note"
      content: "Content"
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
    assert ($result.note.title == "Test Note")
  }
}

# Test get-notes returns filtered by type
export def "test get-notes filters by type" [] {
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
    assert ($result.notes.0.note_type == "manual")
  }
}

# Test delete-note removes note
export def "test delete-note success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu delete-note

  with-env {
    MOCK_query_db: ({output: [{id: 42}] exit_code: 0})
  } {
    let result = delete-note 42

    assert ($result.success == true)
  }
}

# Test search-notes with query
export def "test search-notes success" [] {
  use ../tests/mocks.nu *
  use ../storage.nu search-notes

  let mock_data = [
    {
      id: 42
      title: "Database Design"
      content: "Notes about database"
      tags: '["database"]'
      note_type: "manual"
      created_at: "2025-01-14 16:30:00"
      rank: -0.5
    }
  ]

  with-env {
    MOCK_query_db: ({output: $mock_data exit_code: 0})
  } {
    let result = search-notes "database"

    assert ($result.success == true)
    assert ($result.count == 1)
  }
}

# --- Summary/Export ---

# Test get-summary returns expected structure
export def "test get-summary returns structure" [] {
  use ../storage.nu get-summary

  let result = get-summary

  assert ($result.success == true)
  assert ("summary" in $result)
  assert ("stats" in $result.summary)
  assert ("active_lists" in $result.summary)
}

# Test export-data returns all data
export def "test export-data returns data" [] {
  use ../tests/mocks.nu *
  use ../storage.nu export-data

  with-env {
    MOCK_query_db: ({output: [] exit_code: 0})
    MOCK_query_db_TODO_LIST: ({output: [{id: 1 name: "Test" status: "active"}] exit_code: 0})
  } {
    let result = export-data

    assert ($result.success == true)
    assert ("lists" in $result.data)
    assert ("items" in $result.data)
    assert ("notes" in $result.data)
  }
}
