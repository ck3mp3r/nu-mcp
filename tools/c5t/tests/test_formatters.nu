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
