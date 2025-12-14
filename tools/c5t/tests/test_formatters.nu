# Tests for formatters.nu - output formatting functions

use std/assert

# Test format-todo-created with valid list
export def "test format-todo-created returns formatted output" [] {
  use ../formatters.nu format-todo-created

  let list = {
    name: "Test List"
    id: "20251214-1234"
    status: "active"
    created_at: "2025-12-14 13:45:30"
  }

  let output = format-todo-created $list

  assert ($output | str contains "Test List")
  assert ($output | str contains "20251214-1234")
  assert ($output | str contains "active")
  assert ($output | str contains "2025-12-14 13:45:30")
}

# Test format-todos-list with empty list
export def "test format-todos-list handles empty list" [] {
  use ../formatters.nu format-todos-list

  let output = format-todos-list []

  assert equal $output "No active todo lists found."
}

# Test format-todos-list with single item
export def "test format-todos-list formats single item" [] {
  use ../formatters.nu format-todos-list

  let lists = [
    {
      name: "Feature Work"
      id: "123-456"
      status: "active"
      created_at: "2025-12-14"
    }
  ]

  let output = format-todos-list $lists

  assert ($output | str contains "Active Todo Lists:")
  assert ($output | str contains "Feature Work")
  assert ($output | str contains "123-456")
  assert ($output | str contains "active")
}

# Test format-todos-list with multiple items
export def "test format-todos-list formats multiple items" [] {
  use ../formatters.nu format-todos-list

  let lists = [
    {name: "List 1" id: "id1" status: "active" created_at: "2025-12-14"}
    {name: "List 2" id: "id2" status: "active" created_at: "2025-12-15"}
  ]

  let output = format-todos-list $lists

  assert ($output | str contains "List 1")
  assert ($output | str contains "List 2")
  assert ($output | str contains "id1")
  assert ($output | str contains "id2")
}

# Test format-note-created with valid note
export def "test format-note-created returns formatted output" [] {
  use ../formatters.nu format-note-created

  let note = {
    title: "Architecture Decision"
    id: "note-123"
    note_type: "manual"
    created_at: "2025-12-14 14:00:00"
  }

  let output = format-note-created $note

  assert ($output | str contains "Architecture Decision")
  assert ($output | str contains "note-123")
  assert ($output | str contains "manual")
  assert ($output | str contains "2025-12-14 14:00:00")
}

# Test format-notes-list with empty list
export def "test format-notes-list handles empty list" [] {
  use ../formatters.nu format-notes-list

  let output = format-notes-list []

  assert equal $output "No notes found."
}

# Test format-notes-list with single note
export def "test format-notes-list formats single note" [] {
  use ../formatters.nu format-notes-list

  let notes = [
    {
      title: "Meeting Notes"
      id: "note-1"
      note_type: "manual"
      created_at: "2025-12-14"
      content: "Discussed project timeline and deliverables for Q1 2025"
    }
  ]

  let output = format-notes-list $notes

  assert ($output | str contains "Notes:")
  assert ($output | str contains "Meeting Notes")
  assert ($output | str contains "note-1")
  assert ($output | str contains "Preview:")
}

# Test format-search-results with empty list
export def "test format-search-results handles empty list" [] {
  use ../formatters.nu format-search-results

  let output = format-search-results []

  assert equal $output "No results found."
}

# Test format-search-results with results
export def "test format-search-results formats results" [] {
  use ../formatters.nu format-search-results

  let notes = [
    {
      title: "Search Result 1"
      id: "sr-1"
      note_type: "manual"
      created_at: "2025-12-14"
    }
  ]

  let output = format-search-results $notes

  assert ($output | str contains "Search Results:")
  assert ($output | str contains "Search Result 1")
  assert ($output | str contains "sr-1")
}

# Test format-list-created with all fields
export def "test format-list-created with all fields" [] {
  use ../formatters.nu format-list-created

  let result = {
    id: "20251214-1234"
    name: "Feature Work"
    description: "Implementing new authentication"
    tags: ["backend" "security"]
  }

  let output = format-list-created $result

  assert ($output | str contains "Feature Work")
  assert ($output | str contains "20251214-1234")
  assert ($output | str contains "backend, security")
  assert ($output | str contains "Implementing new authentication")
}

# Test format-list-created with minimal fields
export def "test format-list-created with minimal fields" [] {
  use ../formatters.nu format-list-created

  let result = {
    id: "20251214-5678"
    name: "Bug Fixes"
    description: null
    tags: null
  }

  let output = format-list-created $result

  assert ($output | str contains "Bug Fixes")
  assert ($output | str contains "20251214-5678")
  assert ($output | str contains "none")
}

# Test format-active-lists with empty list
export def "test format-active-lists handles empty list" [] {
  use ../formatters.nu format-active-lists

  let output = format-active-lists []

  assert equal $output "No active todo lists found."
}

# Test format-active-lists with single list
export def "test format-active-lists formats single list" [] {
  use ../formatters.nu format-active-lists

  let lists = [
    {
      id: "20251214-1234"
      name: "Sprint Tasks"
      description: "Q1 2025 sprint items"
      notes: null
      tags: ["sprint" "q1"]
      created_at: "2025-12-14"
      updated_at: "2025-12-14"
    }
  ]

  let output = format-active-lists $lists

  assert ($output | str contains "Active Todo Lists: 1")
  assert ($output | str contains "Sprint Tasks")
  assert ($output | str contains "20251214-1234")
  assert ($output | str contains "sprint, q1")
  assert ($output | str contains "Q1 2025 sprint items")
}

# Test format-active-lists with multiple lists
export def "test format-active-lists formats multiple lists" [] {
  use ../formatters.nu format-active-lists

  let lists = [
    {
      id: "id1"
      name: "List 1"
      description: "First list"
      notes: null
      tags: ["tag1"]
      created_at: "2025-12-14"
      updated_at: "2025-12-14"
    }
    {
      id: "id2"
      name: "List 2"
      description: null
      notes: null
      tags: []
      created_at: "2025-12-15"
      updated_at: "2025-12-15"
    }
  ]

  let output = format-active-lists $lists

  assert ($output | str contains "Active Todo Lists: 2")
  assert ($output | str contains "List 1")
  assert ($output | str contains "List 2")
  assert ($output | str contains "tag1")
  assert ($output | str contains "none")
}

# Test format-notes-updated
export def "test format-notes-updated returns formatted output" [] {
  use ../formatters.nu format-notes-updated

  let output = format-notes-updated "list-123"

  assert ($output | str contains "✓")
  assert ($output | str contains "list-123")
  assert ($output | str contains "Progress notes updated")
}

# Test format-active-lists with notes field
export def "test format-active-lists includes notes" [] {
  use ../formatters.nu format-active-lists

  let lists = [
    {
      id: "list-1"
      name: "Test List"
      description: "Description"
      notes: "Some progress notes"
      tags: ["test"]
      created_at: "2025-12-14"
      updated_at: "2025-12-14"
    }
  ]

  let output = format-active-lists $lists

  assert ($output | str contains "Test List")
  assert ($output | str contains "Some progress notes")
}
