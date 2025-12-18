# Utility functions for c5t tool

# NOTE: ID generation removed - SQLite auto-generates INTEGER PRIMARY KEY
# IDs are now integers auto-assigned by SQLite using last_insert_rowid()

# Get git status for scratchpad
export def get-git-status [] {
  # Check if we're in a git repo - use try/catch since git returns non-zero outside repo
  let is_git_repo = (
    try {
      git rev-parse --git-dir;
      true
    } catch {
      false
    }
  )

  if not $is_git_repo {
    return ["*Not a git repository*"]
  }

  mut lines = []

  # Get current branch
  let branch = (try { git branch --show-current | str trim } catch { "" })
  if $branch != "" {
    $lines = ($lines | append $"- **Branch**: ($branch)")
  }

  # Get working directory status
  let status_output = (try { git status --porcelain } catch { "" })
  let is_clean = ($status_output | str trim | is-empty)

  if $is_clean {
    $lines = ($lines | append "- **Status**: Clean working directory ✓")
  } else {
    let modified_count = ($status_output | lines | where { $in | str starts-with " M" } | length)
    let staged_count = ($status_output | lines | where { $in | str starts-with "M " or $in | str starts-with "A " } | length)
    let untracked_count = ($status_output | lines | where { $in | str starts-with "??" } | length)

    $lines = ($lines | append "- **Status**: Modified working directory")
    if $staged_count > 0 {
      $lines = ($lines | append $"  - Staged: ($staged_count) files")
    }
    if $modified_count > 0 {
      $lines = ($lines | append $"  - Modified: ($modified_count) files")
    }
    if $untracked_count > 0 {
      $lines = ($lines | append $"  - Untracked: ($untracked_count) files")
    }
  }

  # Get last 3 commits
  let commits = (try { git log -3 --oneline --no-decorate | str trim } catch { "" })
  if $commits != "" {
    $lines = ($lines | append "- **Recent commits**:")
    for commit in ($commits | lines) {
      $lines = ($lines | append $"  - ($commit)")
    }
  }

  $lines
}

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

# Validate task update input
export def validate-task-update-input [args: record] {
  if "list_id" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'list_id'"
    }
  }

  if "task_id" not-in $args {
    return {
      valid: false
      error: "Missing required field: 'task_id'"
    }
  }

  {valid: true}
}
