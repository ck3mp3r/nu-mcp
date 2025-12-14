# Utility functions for c5t tool

# NOTE: ID generation removed - SQLite auto-generates INTEGER PRIMARY KEY
# IDs are now integers auto-assigned by SQLite using last_insert_rowid()

# Auto-update scratchpad with generated content
export def auto-update-scratchpad [] {
  use storage.nu *

  # Generate fresh scratchpad content
  let content = generate-scratchpad-template

  # Update scratchpad
  let result = update-scratchpad $content

  # Return success silently
  $result.success
}

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

# Generate scratchpad markdown template from current state
export def generate-scratchpad-template [
  lists: list
  in_progress: list
  completed: list
  high_priority: list
] {
  mut lines = [
    "# Session Context"
    ""
    $"**Last Updated**: (date now | format date '%Y-%m-%d %H:%M:%S')"
    ""
    "---"
    ""
  ]

  # Active Lists Section
  $lines = ($lines | append "## Active Work")
  $lines = ($lines | append "")

  if ($lists | is-empty) {
    $lines = ($lines | append "*No active lists*")
    $lines = ($lines | append "")
  } else {
    for list in $lists {
      let active_count = $list.backlog_count + $list.todo_count + $list.in_progress_count + $list.review_count
      $lines = ($lines | append $"### ($list.name) \(List ID: ($list.id)\)")
      if $list.description != null and $list.description != "" {
        $lines = ($lines | append $"> ($list.description)")
      }
      $lines = ($lines | append "")
      $lines = ($lines | append $"**Progress**: ($list.done_count) done | ($active_count) active \(($list.in_progress_count) in progress, ($list.todo_count) todo, ($list.backlog_count) backlog\)")
      $lines = ($lines | append "")
    }
  }

  # In Progress Items Section
  $lines = ($lines | append "## Currently In Progress")
  $lines = ($lines | append "")

  if ($in_progress | is-empty) {
    $lines = ($lines | append "*No items in progress*")
    $lines = ($lines | append "")
  } else {
    for item in $in_progress {
      let priority_indicator = if $item.priority != null {
        $" [P($item.priority)]"
      } else {
        ""
      }
      $lines = ($lines | append $"- **($item.list_name)**: ($item.content)($priority_indicator)")
      $lines = ($lines | append $"  - Item ID: ($item.id) | Started: ($item.started_at)")
    }
    $lines = ($lines | append "")
  }

  # Recently Completed Section
  $lines = ($lines | append "## Recently Completed")
  $lines = ($lines | append "")

  if ($completed | is-empty) {
    $lines = ($lines | append "*No recently completed items*")
    $lines = ($lines | append "")
  } else {
    for item in $completed {
      let status_emoji = if $item.status == "done" { "✅" } else { "❌" }
      $lines = ($lines | append $"- ($status_emoji) ($item.content) \(($item.list_name) - ($item.completed_at)\)")
    }
    $lines = ($lines | append "")
  }

  # High Priority Next Steps
  $lines = ($lines | append "## High-Priority Next Steps")
  $lines = ($lines | append "")

  if ($high_priority | is-empty) {
    $lines = ($lines | append "*No high-priority items pending*")
    $lines = ($lines | append "")
  } else {
    for item in $high_priority {
      $lines = ($lines | append $"- [P($item.priority)] ($item.content) \(($item.list_name)\)")
      $lines = ($lines | append $"  - Status: ($item.status) | Item ID: ($item.id)")
    }
    $lines = ($lines | append "")
  }

  # Git Status Section (auto-populated)
  $lines = ($lines | append "## Git Status")
  $lines = ($lines | append "")
  let git_info = get-git-status
  $lines = ($lines | append $git_info)
  $lines = ($lines | append "")

  # Key Learnings & Context
  $lines = ($lines | append "## Key Learnings & Context")
  $lines = ($lines | append "")
  $lines = ($lines | append "*[LLM: Add insights, decisions, important context for next session]*")
  $lines = ($lines | append "")

  $lines | str join (char newline)
}
