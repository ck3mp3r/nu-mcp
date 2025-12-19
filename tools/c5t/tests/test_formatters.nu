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

export def "test format-task-lists formats output" [] {
  use ../formatters.nu format-task-lists

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

  let output = format-task-lists $lists "active"

  assert ($output | str contains "Sprint Tasks")
  assert ($output | str contains "sprint")
}

export def "test format-task-lists handles empty" [] {
  use ../formatters.nu format-task-lists

  let output = format-task-lists [] "active"
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
    active_lists: [{name: "Project Alpha" total_count: 10 backlog_count: 5 todo_count: 3 in_progress_count: 2 review_count: 0 done_count: 0 cancelled_count: 0}]
    in_progress: [
      {content: "Working on X" priority: 5 list_name: "Alpha"}
      {content: "Task with null priority" priority: null list_name: "Alpha"}
    ]
    high_priority: []
    recently_completed: []
  }

  let output = format-summary $summary

  # Check key content is present (now in table format)
  assert ($output | str contains "Active Lists")
  assert ($output | str contains "Project Alpha")
  assert ($output | str contains "Working on X")
  assert ($output | str contains "Task with null priority")
}

# Test that tasks are sorted by priority (P1 first, nulls last)
export def "test format-tasks-table sorts by priority" [] {
  use ../formatters.nu format-tasks-table

  let list = {id: 1 name: "Test List"}
  let tasks = [
    {id: 3 content: "No priority" status: "todo" priority: null started_at: null completed_at: null parent_id: null}
    {id: 1 content: "P3 task" status: "todo" priority: 3 started_at: null completed_at: null parent_id: null}
    {id: 2 content: "P1 task" status: "todo" priority: 1 started_at: null completed_at: null parent_id: null}
    {id: 4 content: "P2 task" status: "todo" priority: 2 started_at: null completed_at: null parent_id: null}
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

# Test format-subtasks-list with string IDs (not int)
export def "test format-subtasks-list accepts string parent_id" [] {
  use ../formatters.nu format-subtasks-list

  let parent_id = "cf527fce" # 8-char hex string ID
  let tasks = [
    {id: "abc12345" content: "Subtask 1" status: "todo" priority: 2 started_at: null completed_at: null}
    {id: "def67890" content: "Subtask 2" status: "done" priority: 1 started_at: null completed_at: "2025-01-15"}
  ]

  let output = format-subtasks-list $parent_id $tasks

  assert ($output | str contains "cf527fce") "Should contain parent ID"
  assert ($output | str contains "Subtask 1") "Should contain first subtask"
  assert ($output | str contains "Subtask 2") "Should contain second subtask"
}

# Test format-subtasks-list handles empty list with string ID
export def "test format-subtasks-list handles empty with string id" [] {
  use ../formatters.nu format-subtasks-list

  let output = format-subtasks-list "abcd1234" []
  assert ($output | str contains "No subtasks") "Should show no subtasks message"
  assert ($output | str contains "abcd1234") "Should contain parent ID"
}

# Test format-task-completed accepts string ID
export def "test format-task-completed accepts string id" [] {
  use ../formatters.nu format-task-completed

  let output = format-task-completed "abc12345"
  assert ($output | str contains "abc12345") "Should contain task ID"
  assert ($output | str contains "complete") "Should indicate completion"
}

# Test format-notes-updated accepts string ID
export def "test format-notes-updated accepts string id" [] {
  use ../formatters.nu format-notes-updated

  let output = format-notes-updated "def67890"
  assert ($output | str contains "def67890") "Should contain list ID"
  assert ($output | str contains "notes updated") "Should indicate notes updated"
}

# Test format-item-updated accepts string ID
export def "test format-item-updated accepts string id" [] {
  use ../formatters.nu format-item-updated

  let output = format-item-updated "status" "ghi11111" "done"
  assert ($output | str contains "ghi11111") "Should contain item ID"
  assert ($output | str contains "status") "Should contain field name"
}

# --- format-task-lists tests (renamed from format-active-lists) ---

export def "test format-task-lists active header" [] {
  use ../formatters.nu format-task-lists

  let lists = [{id: "abc12345" name: "Test List" tags: [] description: "" external_ref: null}]
  let output = format-task-lists $lists "active"

  assert ($output | str starts-with "# Active Task Lists")
}

export def "test format-task-lists archived header" [] {
  use ../formatters.nu format-task-lists

  let lists = [{id: "abc12345" name: "Test List" tags: [] description: "" external_ref: null}]
  let output = format-task-lists $lists "archived"

  assert ($output | str starts-with "# Archived Task Lists")
}

export def "test format-task-lists all header" [] {
  use ../formatters.nu format-task-lists

  let lists = [{id: "abc12345" name: "Test List" tags: [] description: "" external_ref: null}]
  let output = format-task-lists $lists "all"

  assert ($output | str starts-with "# All Task Lists")
}

export def "test format-task-lists empty active" [] {
  use ../formatters.nu format-task-lists

  let output = format-task-lists [] "active"
  assert ($output == "No active task lists found.")
}

export def "test format-task-lists empty archived" [] {
  use ../formatters.nu format-task-lists

  let output = format-task-lists [] "archived"
  assert ($output == "No archived task lists found.")
}

export def "test format-task-lists empty all" [] {
  use ../formatters.nu format-task-lists

  let output = format-task-lists [] "all"
  assert ($output == "No task lists found.")
}
