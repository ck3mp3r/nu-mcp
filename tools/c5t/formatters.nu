# Output formatting functions for c5t tool

# Format a todo list creation response
export def format-todo-created [list: record] {
  [
    $"Todo list created: ($list.name)"
    $"ID: ($list.id)"
    $"Status: ($list.status)"
    $"Created: ($list.created_at)"
  ] | str join (char newline)
}

# Format multiple todo lists
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
