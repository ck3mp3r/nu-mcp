# Output formatting functions for c5t tool

# Format a todo list creation response
export def format-list-created [result: record] {
  let tags_str = if $result.tags != null and ($result.tags | is-not-empty) {
    $result.tags | str join ", "
  } else {
    "none"
  }

  let desc_str = if $result.description != null {
    $"\n  Description: ($result.description)"
  } else {
    ""
  }

  [
    $"✓ Todo list created: ($result.name)"
    $"  ID: ($result.id)"
    $"  Tags: ($tags_str)"
    $desc_str
  ] | str join (char newline)
}

# Format active task lists as markdown table
export def format-active-lists [lists: list] {
  if ($lists | is-empty) {
    return "No active task lists found."
  }

  mut lines = [
    $"# Active Task Lists \(($lists | length)\)"
    ""
    "| ID | Name | Tags | Description |"
    "|---:|------|------|-------------|"
  ]

  for list in $lists {
    let tags_str = if ($list.tags | is-not-empty) {
      $list.tags | str join ", "
    } else {
      "-"
    }

    let desc = if $list.description != null and $list.description != "" {
      $list.description | str substring 0..50
    } else {
      "-"
    }

    $lines = ($lines | append $"| ($list.id) | ($list.name) | ($tags_str) | ($desc) |")
  }

  $lines | str join (char newline)
}

# Format list metadata detail
export def format-list-detail [list: record] {
  let tags_str = if $list.tags != null and ($list.tags | is-not-empty) {
    $list.tags | str join ", "
  } else {
    "none"
  }

  let desc_str = if $list.description != null and $list.description != "" {
    $list.description
  } else {
    "none"
  }

  let notes_str = if $list.notes != null and $list.notes != "" {
    $"\n\n**Notes:**\n($list.notes)"
  } else {
    ""
  }

  let archived_str = if $list.archived_at != null {
    $"\n  Archived: ($list.archived_at)"
  } else {
    ""
  }

  [
    $"# ($list.name)"
    $"**ID:** ($list.id)"
    $"**Status:** ($list.status)"
    $"**Tags:** ($tags_str)"
    $"**Description:** ($desc_str)"
    $"**Created:** ($list.created_at)"
    $"**Updated:** ($list.updated_at)"
    $archived_str
    $notes_str
  ] | str join (char newline)
}

# Format a todo list creation response (legacy, kept for compatibility)
export def format-todo-created [list: record] {
  [
    $"Todo list created: ($list.name)"
    $"ID: ($list.id)"
    $"Status: ($list.status)"
    $"Created: ($list.created_at)"
  ] | str join (char newline)
}

# Format multiple todo lists (legacy, kept for compatibility)
export def format-todos-list [lists: list] {
  if ($lists | is-empty) {
    return "No active todo lists found."
  }

  let items = $lists | each {|list|
      [
        $"- ($list.name) [ID: ($list.id)]"
        $"  Status: ($list.status) | Created: ($list.created_at)"
      ] | str join (char newline)
    }

  ["Active Todo Lists:" ...$items] | str join (char newline)
}

# Format a note creation response
export def format-note-created [note: record] {
  [
    $"Note created: ($note.title)"
    $"ID: ($note.id)"
    $"Type: ($note.note_type)"
    $"Created: ($note.created_at)"
  ] | str join (char newline)
}

# Format multiple notes
export def format-notes-list [notes: list] {
  if ($notes | is-empty) {
    return "No notes found."
  }

  let items = $notes | each {|note|
      let preview = $note.content | str substring 0..100
      [
        $"- ($note.title) [ID: ($note.id)]"
        $"  Type: ($note.note_type) | Created: ($note.created_at)"
        $"  Preview: ($preview)..."
      ] | str join (char newline)
    }

  ["Notes:" ...$items] | str join (char newline)
}

# Format search results as markdown table
export def format-search-results [notes: list] {
  if ($notes | is-empty) {
    return "No results found."
  }

  mut lines = [
    $"# Search Results \(($notes | length)\)"
    ""
    "| ID | Type | Title |"
    "|---:|:----:|-------|"
  ]

  for note in $notes {
    let type_emoji = match $note.note_type {
      "manual" => "📝"
      "archived_todo" => "🗃️"
      _ => "📄"
    }

    $lines = ($lines | append $"| ($note.id) | ($type_emoji) | ($note.title) |")
  }

  $lines | str join (char newline)
}

# Format task creation response
export def format-task-created [result: record] {
  let priority_str = if $result.priority != null {
    $" | Priority: ($result.priority)"
  } else {
    ""
  }

  [
    $"✓ Task added"
    $"  ID: ($result.id)"
    $"  Content: ($result.content)"
    $"  Status: ($result.status)($priority_str)"
  ] | str join (char newline)
}

# Format item update response
export def format-item-updated [field: string item_id: int value: any] {
  [
    $"✓ Item ($field) updated"
    $"  ID: ($item_id)"
    $"  New ($field): ($value)"
  ] | str join (char newline)
}

# Format task completion response
export def format-task-completed [task_id: int] {
  [
    $"✓ Task marked as complete"
    $"  ID: ($task_id)"
  ] | str join (char newline)
}

# Format notes update response
export def format-notes-updated [list_id: int] {
  [
    $"✓ Progress notes updated"
    $"  List ID: ($list_id)"
  ] | str join (char newline)
}

# Format item update with auto-archive
export def format-item-updated-with-archive [
  field: string
  item_id: int
  value: any
  note_id: int
] {
  [
    $"✓ Item ($field) updated"
    $"  ID: ($item_id)"
    $"  New ($field): ($value)"
    ""
    $"🗃️  List auto-archived!"
    $"  All items completed - list has been archived as a note"
    $"  Note ID: ($note_id)"
  ] | str join (char newline)
}

# Format item completion with auto-archive
export def format-item-completed-with-archive [
  item_id: int
  note_id: int
] {
  [
    $"✓ Item marked as complete"
    $"  ID: ($item_id)"
    ""
    $"🗃️  List auto-archived!"
    $"  All items completed - list has been archived as a note"
    $"  Note ID: ($note_id)"
  ] | str join (char newline)
}

# Format list of tasks as markdown table
export def format-tasks-table [list: record tasks: list] {
  mut lines = [
    $"# ($list.name)"
    $"**List ID:** ($list.id)"
    ""
  ]

  if ($tasks | is-empty) {
    $lines = ($lines | append "No tasks.")
    return ($lines | str join (char newline))
  }

  # Group by status
  let grouped = $tasks | group-by status

  let status_order = [
    {status: "in_progress" label: "In Progress" emoji: "🔄"}
    {status: "todo" label: "To Do" emoji: "📝"}
    {status: "backlog" label: "Backlog" emoji: "📋"}
    {status: "review" label: "Review" emoji: "👀"}
  ]

  for entry in $status_order {
    if $entry.status in $grouped {
      # Sort by priority (P1 first, nulls last)
      let raw_items = $grouped | get $entry.status
      let with_priority = $raw_items | where priority != null | sort-by priority
      let without_priority = $raw_items | where priority == null
      let status_items = $with_priority | append $without_priority

      $lines = ($lines | append $"## ($entry.emoji) ($entry.label)")
      $lines = ($lines | append "")
      $lines = ($lines | append "| ID | P | Content |")
      $lines = ($lines | append "|---:|:-:|---------|")

      for task in $status_items {
        let priority = if $task.priority != null { $"($task.priority)" } else { "-" }
        $lines = ($lines | append $"| ($task.id) | ($priority) | ($task.content) |")
      }
      $lines = ($lines | append "")
    }
  }

  $lines | str join (char newline)
}

# Format list with items (legacy bullet format)
export def format-items-list [list: record items: list] {
  if ($items | is-empty) {
    return [
      $"Todo List: ($list.name)"
      $"  ID: ($list.id)"
      ""
      "No items in this list."
    ] | str join (char newline)
  }

  # Group items by status
  let grouped = $items | group-by status

  # Status order and emoji mapping
  let status_order = [
    {status: "backlog" emoji: "📋" label: "Backlog"}
    {status: "todo" emoji: "📝" label: "To Do"}
    {status: "in_progress" emoji: "🔄" label: "In Progress"}
    {status: "review" emoji: "👀" label: "Review"}
    {status: "done" emoji: "✅" label: "Done"}
    {status: "cancelled" emoji: "❌" label: "Cancelled"}
  ]

  mut output_lines = [
    $"Todo List: ($list.name)"
    $"  ID: ($list.id)"
    ""
  ]

  # Add each status group
  for status_info in $status_order {
    let status = $status_info.status
    if $status in $grouped {
      # Sort by priority (P1 first, nulls last)
      let raw_items = $grouped | get $status
      let with_priority = $raw_items | where priority != null | sort-by priority
      let without_priority = $raw_items | where priority == null
      let status_items = $with_priority | append $without_priority
      let count = $status_items | length

      $output_lines = ($output_lines | append $"($status_info.emoji) ($status_info.label) \(($count)\):")

      for item in $status_items {
        let priority_str = if $item.priority != null {
          $" [P($item.priority)]"
        } else {
          ""
        }

        let time_info = if $item.status == "done" and $item.completed_at != null {
          $" - completed ($item.completed_at)"
        } else if $item.status == "in_progress" and $item.started_at != null {
          $" - started ($item.started_at)"
        } else {
          ""
        }

        $output_lines = ($output_lines | append $"  • ($item.content)($priority_str)($time_info)")
        $output_lines = ($output_lines | append $"    ID: ($item.id)")
      }

      $output_lines = ($output_lines | append "")
    }
  }

  $output_lines | str join (char newline)
}

# Format manual note creation response
export def format-note-created-manual [result: record] {
  let tags_str = if "tags" in $result and $result.tags != null and ($result.tags | is-not-empty) {
    $result.tags | str join ", "
  } else {
    "none"
  }

  let created_at_str = if "created_at" in $result {
    $"  Created at: ($result.created_at)"
  } else {
    ""
  }

  let lines = [
    $"✓ Note created: ($result.title)"
    $"  ID: ($result.id)"
    $"  Tags: ($tags_str)"
  ]

  let lines_with_created = if $created_at_str != "" {
    $lines | append $created_at_str
  } else {
    $lines
  }

  $lines_with_created | str join (char newline)
}

# Format list of notes as markdown table
export def format-notes-list-detailed [notes: list] {
  if ($notes | is-empty) {
    return "No notes found."
  }

  mut lines = [
    $"# Notes \(($notes | length)\)"
    ""
    "| ID | Type | Title | Tags |"
    "|---:|:----:|-------|------|"
  ]

  for note in $notes {
    let tags_str = if ($note.tags | is-not-empty) {
      $note.tags | str join ", "
    } else {
      "-"
    }

    let type_emoji = match $note.note_type {
      "manual" => "📝"
      "archived_todo" => "🗃️"
      _ => "📄"
    }

    $lines = ($lines | append $"| ($note.id) | ($type_emoji) | ($note.title) | ($tags_str) |")
  }

  $lines | str join (char newline)
}

# Format detailed note view
export def format-note-detail [note: record] {
  let tags_str = if ($note.tags | is-not-empty) {
    $note.tags | str join ", "
  } else {
    "none"
  }

  [
    $"Note: ($note.title)"
    $"  ID: ($note.id)"
    $"  Type: ($note.note_type) | Tags: ($tags_str)"
    $"  Created: ($note.created_at) | Updated: ($note.updated_at)"
    ""
    "---"
    ""
    $note.content
  ] | str join (char newline)
}

# Format comprehensive summary/overview
export def format-summary [summary: record] {
  mut lines = []

  # Header
  $lines = ($lines | append "# C5T Summary")
  $lines = ($lines | append "")

  # Stats overview
  let stats = $summary.stats
  if $stats.active_lists == 0 {
    $lines = ($lines | append "## Status")
    $lines = ($lines | append "No active lists")
    $lines = ($lines | append "")
    return ($lines | str join (char newline))
  }

  $lines = ($lines | append "## Overview")
  $lines = ($lines | append $"• Active Lists: ($stats.active_lists)")
  $lines = ($lines | append $"• Total Tasks: ($stats.total_tasks)")
  $lines = ($lines | append "")

  $lines = ($lines | append "### By Status")
  $lines = ($lines | append $"• 📋 Backlog: ($stats.backlog_total)")
  $lines = ($lines | append $"• 📝 Todo: ($stats.todo_total)")
  $lines = ($lines | append $"• 🔄 In Progress: ($stats.in_progress_total)")
  $lines = ($lines | append $"• 👀 Review: ($stats.review_total)")
  $lines = ($lines | append $"• ✅ Done: ($stats.done_total)")
  $lines = ($lines | append $"• ❌ Cancelled: ($stats.cancelled_total)")
  $lines = ($lines | append "")

  # Active Lists
  if ($summary.active_lists | length) > 0 {
    $lines = ($lines | append "## Active Lists")
    for list in $summary.active_lists {
      $lines = ($lines | append $"• ($list.name) - ($list.total_count) tasks \(($list.in_progress_count) in progress, ($list.todo_count) todo\)")
    }
    $lines = ($lines | append "")
  }

  # In Progress Tasks
  if ($summary.in_progress | length) > 0 {
    $lines = ($lines | append "## In Progress")
    for task in $summary.in_progress {
      let priority_marker = if $task.priority != null and $task.priority >= 4 { "🔥 " } else { "" }
      $lines = ($lines | append $"• ($priority_marker)($task.content) [($task.list_name)]")
    }
    $lines = ($lines | append "")
  } else {
    $lines = ($lines | append "## In Progress")
    $lines = ($lines | append "No tasks in progress")
    $lines = ($lines | append "")
  }

  # High Priority Next Steps
  if ($summary.high_priority | length) > 0 {
    $lines = ($lines | append "## High Priority (P4-P5)")
    for task in $summary.high_priority {
      let status_emoji = if $task.status == "todo" { "📝" } else { "📋" }
      $lines = ($lines | append $"• ($status_emoji) P($task.priority): ($task.content) [($task.list_name)]")
    }
    $lines = ($lines | append "")
  }

  # Recently Completed
  if ($summary.recently_completed | length) > 0 {
    $lines = ($lines | append "## Recently Completed")
    let show_count = if ($summary.recently_completed | length) > 5 { 5 } else { ($summary.recently_completed | length) }
    for task in ($summary.recently_completed | first $show_count) {
      $lines = ($lines | append $"• ✅ ($task.content) [($task.list_name)]")
    }
    $lines = ($lines | append "")
  }

  # Session context tip
  $lines = ($lines | append "---")
  $lines = ($lines | append "💡 For detailed session context, check `c5t_list_notes {\"tags\": [\"session\"]}`")

  $lines | str join (char newline)
}

# Format list of repositories as markdown table
export def format-repos-list [repos: list] {
  if ($repos | is-empty) {
    return "No repositories found."
  }

  mut lines = [
    $"# Repositories \(($repos | length)\)"
    ""
    "| ID | Remote | Path |"
    "|---:|--------|------|"
  ]

  for repo in $repos {
    $lines = ($lines | append $"| ($repo.id) | ($repo.remote) | ($repo.path) |")
  }

  $lines | str join (char newline)
}
