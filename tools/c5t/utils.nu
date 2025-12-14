# Utility functions for c5t tool

# NOTE: ID generation removed - SQLite auto-generates INTEGER PRIMARY KEY
# IDs are now integers auto-assigned by SQLite using last_insert_rowid()

# Validate list input
export def validate-list-input [args: record] {
  if "name" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'name'"
    }
  }

  if ($args.name | str trim | is-empty) {
    return {
      valid: false
      error: "Field 'name' cannot be empty"
    }
  }

  {valid: true}
}

# Validate item input
export def validate-item-input [args: record] {
  if "list_id" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'list_id'"
    }
  }

  if "content" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'content'"
    }
  }

  if ($args.content | str trim | is-empty) {
    return {
      valid: false
      error: "Field 'content' cannot be empty"
    }
  }

  {valid: true}
}

# Validate note input
export def validate-note-input [args: record] {
  if "title" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'title'"
    }
  }

  if "content" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'content'"
    }
  }

  if ($args.title | str trim | is-empty) {
    return {
      valid: false
      error: "Field 'title' cannot be empty"
    }
  }

  if ($args.content | str trim | is-empty) {
    return {
      valid: false
      error: "Field 'content' cannot be empty"
    }
  }

  {valid: true}
}

# Validate item status
export def validate-status [status: string] {
  let valid_statuses = ["backlog" "todo" "in_progress" "review" "done" "cancelled"]

  if $status in $valid_statuses {
    {valid: true}
  } else {
    {
      valid: false
      error: $"Invalid status: '($status)'. Must be one of: ($valid_statuses | str join ', ')"
    }
  }
}

# Validate item priority
export def validate-priority [priority: int] {
  if $priority >= 1 and $priority <= 5 {
    {valid: true}
  } else {
    {
      valid: false
      error: $"Invalid priority: ($priority). Must be between 1 and 5"
    }
  }
}

# Validate item update input
export def validate-item-update-input [args: record] {
  if "list_id" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'list_id'"
    }
  }

  if "item_id" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'item_id'"
    }
  }

  {valid: true}
}
