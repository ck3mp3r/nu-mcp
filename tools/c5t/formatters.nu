# Output formatting functions for c5t tool

# Helper: Convert list to nushell table string (removes index column)
def to-nu-table [] {
  $in | table --index false | into string
}

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

# Format active task lists as nushell table
export def format-active-lists [lists: list] {
  if ($lists | is-empty) {
    return "No active task lists found."
  }

  let header = $"# Active Task Lists \(($lists | length)\)\n\n"

  let table_data = $lists | each {|list|
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

      {ID: $list.id Name: $list.name Tags: $tags_str Description: $desc}
    }

  $header + ($table_data | to-nu-table)
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

# Format search results as nushell table
export def format-search-results [notes: list] {
  if ($notes | is-empty) {
    return "No results found."
  }

  let header = $"# Search Results \(($notes | length)\)\n\n"

  let table_data = $notes | each {|note|
      let type_emoji = match $note.note_type {
        "manual" => "📝"
        "archived_todo" => "🗃️"
        _ => "📄"
      }

      {ID: $note.id Type: $type_emoji Title: $note.title}
    }

  $header + ($table_data | to-nu-table)
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
# Format list of tasks as nushell table
export def format-tasks-table [list: record tasks: list] {
  mut output = $"# ($list.name)\n**List ID:** ($list.id)\n\n"

  if ($tasks | is-empty) {
    return ($output + "No tasks.")
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

      let table_data = $status_items | each {|task|
          let priority = if $task.priority != null { $task.priority } else { "-" }
          {ID: $task.id P: $priority Content: $task.content}
        }

      $output = $output + $"## ($entry.emoji) ($entry.label)\n\n"
      $output = $output + ($table_data | to-nu-table) + "\n\n"
    }
  }

  $output | str trim
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

# Format list of notes as nushell table
export def format-notes-list-detailed [notes: list] {
  if ($notes | is-empty) {
    return "No notes found."
  }

  let header = $"# Notes \(($notes | length)\)\n\n"

  let table_data = $notes | each {|note|
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

      {ID: $note.id Type: $type_emoji Title: $note.title Tags: $tags_str}
    }

  $header + ($table_data | to-nu-table)
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
# Format summary as nushell tables
export def format-summary [summary: record] {
  mut output = "# C5T Summary\n\n"

  let stats = $summary.stats
  if $stats.active_lists == 0 {
    return ($output + "No active lists.")
  }

  # Stats table
  $output = $output + "## Status\n\n"
  let status_data = [
    {Status: "📋 Backlog" Count: $stats.backlog_total}
    {Status: "📝 Todo" Count: $stats.todo_total}
    {Status: "🔄 In Progress" Count: $stats.in_progress_total}
    {Status: "👀 Review" Count: $stats.review_total}
    {Status: "✅ Done" Count: $stats.done_total}
    {Status: "❌ Cancelled" Count: $stats.cancelled_total}
  ]
  $output = $output + ($status_data | to-nu-table) + "\n\n"

  # Active Lists table
  if ($summary.active_lists | length) > 0 {
    $output = $output + "## Active Lists\n\n"
    let lists_data = $summary.active_lists | each {|list|
        {Name: $list.name Total: $list.total_count "In Progress": $list.in_progress_count Todo: $list.todo_count}
      }
    $output = $output + ($lists_data | to-nu-table) + "\n\n"
  }

  # In Progress table
  $output = $output + "## In Progress\n\n"
  if ($summary.in_progress | length) > 0 {
    let in_progress_data = $summary.in_progress | each {|task|
        let p = if $task.priority != null { $task.priority } else { "-" }
        {P: $p Task: $task.content List: $task.list_name}
      }
    $output = $output + ($in_progress_data | to-nu-table) + "\n\n"
  } else {
    $output = $output + "No tasks in progress.\n\n"
  }

  # High Priority table
  if ($summary.high_priority | length) > 0 {
    $output = $output + "## High Priority\n\n"
    let high_priority_data = $summary.high_priority | each {|task|
        {P: $task.priority Task: $task.content List: $task.list_name}
      }
    $output = $output + ($high_priority_data | to-nu-table) + "\n\n"
  }

  # Recently Completed table
  if ($summary.recently_completed | length) > 0 {
    $output = $output + "## Recently Completed\n\n"
    let show_count = [($summary.recently_completed | length) 5] | math min
    let completed_data = $summary.recently_completed | first $show_count | each {|task|
        {Task: $task.content List: $task.list_name}
      }
    $output = $output + ($completed_data | to-nu-table) + "\n"
  }

  $output | str trim
}

# Format list of repositories as nushell table
export def format-repos-list [repos: list] {
  if ($repos | is-empty) {
    return "No repositories found."
  }

  let header = $"# Repositories \(($repos | length)\)\n\n"

  let table_data = $repos | each {|repo|
      {ID: $repo.id Remote: $repo.remote Path: $repo.path}
    }

  $header + ($table_data | to-nu-table)
}
