# Output formatting functions for c5t tool

# Format a todo list creation response
export def format-todo-created [list: record] {
  let lines = [
    $"Todo list created: ($list.name)"
    $"ID: ($list.id)"
    $"Status: ($list.status)"
    $"Created: ($list.created_at)"
  ]
  $lines | str join (char newline)
}

# Format multiple todo lists
export def format-todos-list [lists: list] {
  if ($lists | is-empty) {
    return "No active todo lists found."
  }

  let items = $lists | each {|list|
    let list_id = $list.id
    let list_name = $list.name
    let list_status = $list.status
    let list_created = $list.created_at
    let lines = [
      $"- ($list_name) [ID: ($list_id)]"
      $"  Status: ($list_status) | Created: ($list_created)"
    ]
    $lines | str join (char newline)
  }

  let output = $items | str join (char newline)
  let header = "Active Todo Lists:"
  [$header $output] | str join (char newline)
}

# Format a note creation response
export def format-note-created [note: record] {
  let lines = [
    $"Note created: ($note.title)"
    $"ID: ($note.id)"
    $"Type: ($note.note_type)"
    $"Created: ($note.created_at)"
  ]
  $lines | str join (char newline)
}

# Format multiple notes
export def format-notes-list [notes: list] {
  if ($notes | is-empty) {
    return "No notes found."
  }

  let items = $notes | each {|note|
    let preview = $note.content | str substring 0..100
    let note_id = $note.id
    let note_title = $note.title
    let note_type = $note.note_type
    let note_created = $note.created_at
    let lines = [
      $"- ($note_title) [ID: ($note_id)]"
      $"  Type: ($note_type) | Created: ($note_created)"
      $"  Preview: ($preview)..."
    ]
    $lines | str join (char newline)
  }

  let output = $items | str join (char newline)
  let header = "Notes:"
  [$header $output] | str join (char newline)
}

# Format search results
export def format-search-results [notes: list] {
  if ($notes | is-empty) {
    return "No results found."
  }

  let items = $notes | each {|note|
    let note_id = $note.id
    let note_title = $note.title
    let note_type = $note.note_type
    let note_created = $note.created_at
    let lines = [
      $"- ($note_title) [ID: ($note_id)]"
      $"  Type: ($note_type) | Created: ($note_created)"
    ]
    $lines | str join (char newline)
  }

  let output = $items | str join (char newline)
  let header = "Search Results:"
  [$header $output] | str join (char newline)
}
