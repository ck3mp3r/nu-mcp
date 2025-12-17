# Tests for formatters.nu - output formatting
# Focus: One test per formatter to verify basic output

use std/assert

export def "test format-list-created formats output" [] {
  use ../formatters.nu format-list-created

  let result = {id: 1234 name: "Test" description: "Desc" tags: ["tag1"]}
  let output = format-list-created $result

  assert ($output | str contains "Test")
  assert ($output | str contains "1234")
}

export def "test format-active-lists formats output" [] {
  use ../formatters.nu format-active-lists

  let lists = [
    {
      id: 1
      name: "Sprint Tasks"
      description: "Q1 sprint"
      notes: null
      tags: ["sprint"]
      created_at: "2025-12-14"
      updated_at: "2025-12-14"
    }
  ]

  let output = format-active-lists $lists

  assert ($output | str contains "Sprint Tasks")
  assert ($output | str contains "sprint")
}

export def "test format-active-lists handles empty" [] {
  use ../formatters.nu format-active-lists

  let output = format-active-lists []
  assert ($output | str contains "No active")
}

export def "test format-note-detail formats output" [] {
  use ../formatters.nu format-note-detail

  let note = {
    title: "Architecture"
    id: 789
    note_type: "manual"
    tags: ["arch"]
    created_at: "2025-01-14"
    updated_at: "2025-01-14"
    content: "Decision content here"
  }

  let output = format-note-detail $note

  assert ($output | str contains "Architecture")
  assert ($output | str contains "789")
  assert ($output | str contains "Decision content")
}

export def "test format-notes-list-detailed formats output" [] {
  use ../formatters.nu format-notes-list-detailed

  let notes = [
    {
      title: "Meeting Notes"
      id: 123
      note_type: "manual"
      tags: ["meeting"]
      created_at: "2025-01-14"
      content: "Discussed project timeline"
    }
  ]

  let output = format-notes-list-detailed $notes

  assert ($output | str contains "Meeting Notes")
  assert ($output | str contains "📝")
}

export def "test format-search-results formats output" [] {
  use ../formatters.nu format-search-results

  let notes = [
    {
      title: "Result"
      id: "sr-1"
      note_type: "manual"
      created_at: "2025-12-14"
    }
  ]

  let output = format-search-results $notes

  assert ($output | str contains "Search Results")
  assert ($output | str contains "Result")
}

export def "test format-search-results handles empty" [] {
  use ../formatters.nu format-search-results

  let output = format-search-results []
  assert ($output | str contains "No results")
}

export def "test format-summary formats output" [] {
  use ../formatters.nu format-summary

  let summary = {
    stats: {
      active_lists: 2
      total_tasks: 15
      backlog_total: 5
      todo_total: 4
      in_progress_total: 3
      review_total: 1
      done_total: 2
      cancelled_total: 0
    }
    active_lists: [{name: "Project Alpha" total_count: 10 in_progress_count: 2 todo_count: 3}]
    in_progress: [{content: "Working on X" priority: 5 list_name: "Alpha"}]
    high_priority: []
    recently_completed: []
  }

  let output = format-summary $summary

  assert ($output | str contains "Active Lists: 2")
  assert ($output | str contains "Project Alpha")
}

# Test that tasks are sorted by priority (P1 first, nulls last)
export def "test format-tasks-table sorts by priority" [] {
  use ../formatters.nu format-tasks-table

  let list = {id: 1 name: "Test List"}
  let tasks = [
    {id: 3 content: "No priority" status: "todo" priority: null started_at: null completed_at: null}
    {id: 1 content: "P3 task" status: "todo" priority: 3 started_at: null completed_at: null}
    {id: 2 content: "P1 task" status: "todo" priority: 1 started_at: null completed_at: null}
    {id: 4 content: "P2 task" status: "todo" priority: 2 started_at: null completed_at: null}
  ]

  let output = format-tasks-table $list $tasks

  # P1 should appear before P2, P2 before P3, P3 before null
  let p1_pos = $output | str index-of "P1 task"
  let p2_pos = $output | str index-of "P2 task"
  let p3_pos = $output | str index-of "P3 task"
  let no_priority_pos = $output | str index-of "No priority"

  assert ($p1_pos < $p2_pos) "P1 should come before P2"
  assert ($p2_pos < $p3_pos) "P2 should come before P3"
  assert ($p3_pos < $no_priority_pos) "P3 should come before tasks without priority"
}

# Test that format-items-list also sorts by priority (legacy formatter)
export def "test format-items-list sorts by priority" [] {
  use ../formatters.nu format-items-list

  let list = {id: 1 name: "Test List"}
  let items = [
    {id: 3 content: "No priority" status: "backlog" priority: null started_at: null completed_at: null}
    {id: 1 content: "P3 item" status: "backlog" priority: 3 started_at: null completed_at: null}
    {id: 2 content: "P1 item" status: "backlog" priority: 1 started_at: null completed_at: null}
    {id: 4 content: "P2 item" status: "backlog" priority: 2 started_at: null completed_at: null}
  ]

  let output = format-items-list $list $items

  # P1 should appear before P2, P2 before P3, P3 before null
  let p1_pos = $output | str index-of "P1 item"
  let p2_pos = $output | str index-of "P2 item"
  let p3_pos = $output | str index-of "P3 item"
  let no_priority_pos = $output | str index-of "No priority"

  assert ($p1_pos < $p2_pos) "P1 should come before P2"
  assert ($p2_pos < $p3_pos) "P2 should come before P3"
  assert ($p3_pos < $no_priority_pos) "P3 should come before items without priority"
}
