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

# Format active todo lists
export def format-active-lists [lists: list] {
  if ($lists | is-empty) {
    return "No active todo lists found."
  }

  let items = $lists | each {|list|
    let tags_str = if ($list.tags | is-not-empty) {
      $list.tags | str join ", "
    } else {
      "none"
    }

    let desc = if $list.description != null and $list.description != "" {
      $"\n    ($list.description)"
    } else {
      ""
    }

    let notes = if $list.notes != null and $list.notes != "" {
      $"\n    Notes: ($list.notes)"
    } else {
      ""
    }

    [
      $"  • ($list.name)"
      $"    ID: ($list.id) | Tags: ($tags_str)"
      $desc
      $notes
    ] | str join (char newline)
  }

  let count = $lists | length
  [
    $"Active Todo Lists: ($count)"
    ""
    ...$items
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

# Format search results
export def format-search-results [notes: list] {
  if ($notes | is-empty) {
    return "No results found."
  }

  let items = $notes | each {|note|
    [
      $"- ($note.title) [ID: ($note.id)]"
      $"  Type: ($note.note_type) | Created: ($note.created_at)"
    ] | str join (char newline)
  }

  ["Search Results:" ...$items] | str join (char newline)
}

# Format item creation response
export def format-item-created [result: record] {
  let priority_str = if $result.priority != null {
    $" | Priority: ($result.priority)"
  } else {
    ""
  }

  [
    $"✓ Todo item added"
    $"  ID: ($result.id)"
    $"  Content: ($result.content)"
    $"  Status: ($result.status)($priority_str)"
  ] | str join (char newline)
}

# Format item update response
export def format-item-updated [field: string item_id: string value: any] {
  [
    $"✓ Item ($field) updated"
    $"  ID: ($item_id)"
    $"  New ($field): ($value)"
  ] | str join (char newline)
}

# Format item completion response
export def format-item-completed [item_id: string] {
  [
    $"✓ Item marked as complete"
    $"  ID: ($item_id)"
  ] | str join (char newline)
}

# Format notes update response
export def format-notes-updated [list_id: string] {
  [
    $"✓ Progress notes updated"
    $"  List ID: ($list_id)"
  ] | str join (char newline)
}

# Format item update with auto-archive
export def format-item-updated-with-archive [
  field: string
  item_id: string
  value: any
  note_id: string
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
  item_id: string
  note_id: string
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

# Format list with items
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
      let status_items = $grouped | get $status
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
