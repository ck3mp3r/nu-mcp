# Tests for formatters.nu - output formatting functions

use std/assert

# Test format-todo-created with valid list
export def "test format-todo-created returns formatted output" [] {
  use ../formatters.nu format-todo-created

  let list = {
    name: "Test List"
    id: 1234
    status: "active"
    created_at: "2025-12-14 13:45:30"
  }

  let output = format-todo-created $list

  assert ($output | str contains "Test List")
  assert ($output | str contains 1234)
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
    {name: "List 1" id: 1 status: "active" created_at: "2025-12-14"}
    {name: "List 2" id: 2 status: "active" created_at: "2025-12-15"}
  ]

  let output = format-todos-list $lists

  assert ($output | str contains "List 1")
  assert ($output | str contains "List 2")
  assert ($output | str contains 1)
  assert ($output | str contains 2)
}

# Test format-note-created with valid note
export def "test format-note-created returns formatted output" [] {
  use ../formatters.nu format-note-created

  let note = {
    title: "Architecture Decision"
    id: 123
    note_type: "manual"
    created_at: "2025-12-14 14:00:00"
  }

  let output = format-note-created $note

  assert ($output | str contains "Architecture Decision")
  assert ($output | str contains 123)
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
      id: 1
      note_type: "manual"
      created_at: "2025-12-14"
      content: "Discussed project timeline and deliverables for Q1 2025"
    }
  ]

  let output = format-notes-list $notes

  assert ($output | str contains "Notes:")
  assert ($output | str contains "Meeting Notes")
  assert ($output | str contains 1)
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
    id: 1234
    name: "Feature Work"
    description: "Implementing new authentication"
    tags: ["backend" "security"]
  }

  let output = format-list-created $result

  assert ($output | str contains "Feature Work")
  assert ($output | str contains 1234)
  assert ($output | str contains "backend, security")
  assert ($output | str contains "Implementing new authentication")
}

# Test format-list-created with minimal fields
export def "test format-list-created with minimal fields" [] {
  use ../formatters.nu format-list-created

  let result = {
    id: 5678
    name: "Bug Fixes"
    description: null
    tags: null
  }

  let output = format-list-created $result

  assert ($output | str contains "Bug Fixes")
  assert ($output | str contains 5678)
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
      id: 1234
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
  assert ($output | str contains 1234)
  assert ($output | str contains "sprint, q1")
  assert ($output | str contains "Q1 2025 sprint items")
}

# Test format-active-lists with multiple lists
export def "test format-active-lists formats multiple lists" [] {
  use ../formatters.nu format-active-lists

  let lists = [
    {
      id: 1
      name: "List 1"
      description: "First list"
      notes: null
      tags: ["tag1"]
      created_at: "2025-12-14"
      updated_at: "2025-12-14"
    }
    {
      id: 2
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

  let output = format-notes-updated 123

  assert ($output | str contains "✓")
  assert ($output | str contains 123)
  assert ($output | str contains "Progress notes updated")
}

# Test format-active-lists with notes field
export def "test format-active-lists includes notes" [] {
  use ../formatters.nu format-active-lists

  let lists = [
    {
      id: 1
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

# Test format-note-created-manual with valid note
export def "test format-note-created-manual returns formatted output" [] {
  use ../formatters.nu format-note-created-manual

  let note = {
    title: "Architecture Decision"
    id: 9999
    tags: ["architecture" "backend"]
  }

  let output = format-note-created-manual $note

  assert ($output | str contains "Architecture Decision")
  assert ($output | str contains 9999)
  assert ($output | str contains "architecture, backend")
}

# Test format-notes-list-detailed with empty list
export def "test format-notes-list-detailed handles empty list" [] {
  use ../formatters.nu format-notes-list-detailed

  let output = format-notes-list-detailed []

  assert equal $output "No notes found."
}

# Test format-notes-list-detailed with single note
export def "test format-notes-list-detailed formats single note" [] {
  use ../formatters.nu format-notes-list-detailed

  let notes = [
    {
      title: "Meeting Notes"
      id: 123
      note_type: "manual"
      tags: ["meeting" "planning"]
      created_at: "2025-01-14 16:30:00"
      content: "Discussed project timeline and deliverables for Q1 2025. Team agreed on sprint structure."
    }
  ]

  let output = format-notes-list-detailed $notes

  assert ($output | str contains "Notes: 1")
  assert ($output | str contains "Meeting Notes")
  assert ($output | str contains 123)
  assert ($output | str contains "📝") # Manual emoji
  assert ($output | str contains "meeting, planning")
  assert ($output | str contains "Preview:")
  assert ($output | str contains "Discussed project timeline")
}

# Test format-notes-list-detailed with archived_todo note
export def "test format-notes-list-detailed shows archived emoji" [] {
  use ../formatters.nu format-notes-list-detailed

  let notes = [
    {
      title: "Completed Sprint"
      id: 456
      note_type: "archived_todo"
      tags: []
      created_at: "2025-01-14 16:30:00"
      content: "Sprint completed successfully"
    }
  ]

  let output = format-notes-list-detailed $notes

  assert ($output | str contains "🗃️") # Archived emoji
  assert ($output | str contains "Completed Sprint")
}

# Test format-note-detail with full note
export def "test format-note-detail shows full content" [] {
  use ../formatters.nu format-note-detail

  let note = {
    title: "Architecture Decision"
    id: 789
    note_type: "manual"
    tags: ["architecture" "backend"]
    created_at: "2025-01-14 16:30:00"
    updated_at: "2025-01-14 17:00:00"
    content: "# Architecture Decision

We decided to use Rust for the backend service.

## Reasons
- Performance
- Memory safety
- Great ecosystem"
  }

  let output = format-note-detail $note

  assert ($output | str contains "Architecture Decision")
  assert ($output | str contains 789)
  assert ($output | str contains "Type: manual")
  assert ($output | str contains "Tags: architecture, backend")
  assert ($output | str contains "Created: 2025-01-14 16:30:00")
  assert ($output | str contains "Updated: 2025-01-14 17:00:00")
  assert ($output | str contains "# Architecture Decision")
  assert ($output | str contains "Performance")
  assert ($output | str contains "Memory safety")
}

# Test format-note-detail with minimal note (no tags)
export def "test format-note-detail handles no tags" [] {
  use ../formatters.nu format-note-detail

  let note = {
    title: "Simple Note"
    id: 0
    note_type: "manual"
    tags: []
    created_at: "2025-01-14 16:30:00"
    updated_at: "2025-01-14 16:30:00"
    content: "Just a simple note"
  }

  let output = format-note-detail $note

  assert ($output | str contains "Simple Note")
  assert ($output | str contains "Tags: none")
  assert ($output | str contains "Just a simple note")
}

# --- Summary Formatter Tests (Task 17) ---

# Test format-summary with data
export def "test format-summary with active work" [] {
  use ../formatters.nu format-summary

  let summary = {
    stats: {
      active_lists: 2
      total_items: 15
      backlog_total: 5
      todo_total: 4
      in_progress_total: 3
      review_total: 1
      done_total: 2
      cancelled_total: 0
    }
    active_lists: [
      {name: "Project Alpha" total_count: 10 in_progress_count: 2 todo_count: 3}
      {name: "Project Beta" total_count: 5 in_progress_count: 1 todo_count: 1}
    ]
    in_progress: [
      {content: "Working on feature X" priority: 5 list_name: "Project Alpha"}
      {content: "Bug fix in progress" priority: 4 list_name: "Project Beta"}
    ]
    high_priority: [
      {content: "Critical security fix" priority: 5 status: "todo" list_name: "Project Alpha"}
    ]
    recently_completed: [
      {content: "Completed task" completed_at: "2025-12-14 10:00:00" list_name: "Project Alpha"}
    ]
  }

  let output = format-summary $summary

  # Should contain stats summary
  assert ($output | str contains "Active Lists: 2")
  assert ($output | str contains "Total Items: 15")

  # Should list active lists
  assert ($output | str contains "Project Alpha")
  assert ($output | str contains "Project Beta")

  # Should show in-progress items
  assert ($output | str contains "Working on feature X")
  assert ($output | str contains "Bug fix in progress")

  # Should show high-priority items
  assert ($output | str contains "Critical security fix")

  # Should show session note tip
  assert ($output | str contains "session")
}

# Test format-summary with no activity
export def "test format-summary with no activity" [] {
  use ../formatters.nu format-summary

  let summary = {
    stats: {
      active_lists: 0
      total_items: 0
      backlog_total: 0
      todo_total: 0
      in_progress_total: 0
      review_total: 0
      done_total: 0
      cancelled_total: 0
    }
    active_lists: []
    in_progress: []
    high_priority: []
    recently_completed: []
  }

  let output = format-summary $summary

  # Should indicate no activity
  assert ($output | str contains "No active lists")
  # Formatter returns early when no lists, so won't show in-progress section
  assert (not ($output | str contains "In Progress"))
}
