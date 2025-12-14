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

    [
      $"  • ($list.name)"
      $"    ID: ($list.id) | Tags: ($tags_str)"
      $desc
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
