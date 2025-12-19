# Sync functionality for c5t
# Handles git operations and JSONL file format for cross-machine sync

# =============================================================================
# Git Helpers
# =============================================================================

# Check if a directory is a git repository
export def is-git-repo [path: string]: nothing -> bool {
  let git_dir = ($path | path join ".git")
  $git_dir | path exists
}

# Check if a git repository has a clean working tree (no uncommitted changes)
export def git-status-clean [path: string]: nothing -> bool {
  cd $path
  let status = (^git status --porcelain | str trim)
  cd -
  ($status | is-empty)
}

# Pull latest changes from remote
# Returns: {success: bool, message: string}
export def git-pull [path: string]: nothing -> record<success: bool, message: string> {
  cd $path
  try {
    let output = (do { ^git pull } | complete | get stdout | str trim)
    cd -
    {success: true message: $output}
  } catch {|err|
    cd -
    {success: false message: $"Git pull failed: ($err.msg)"}
  }
}

# Add all changes, commit with message, and push
# Returns: {success: bool, message: string}
export def git-commit-push [path: string message: string]: nothing -> record<success: bool, message: string> {
  cd $path
  try {
    ^git add -A
    let status = (^git status --porcelain | str trim)

    if ($status | is-empty) {
      cd -
      return {success: true message: "Nothing to commit"}
    }

    ^git commit -m $message --quiet
    let push_output = (do { ^git push } | complete | get stdout | str trim)
    cd -
    {success: true message: $push_output}
  } catch {|err|
    cd -
    {success: false message: $"Git commit/push failed: ($err.msg)"}
  }
}

# =============================================================================
# JSONL Helpers
# =============================================================================

# Convert a list of records to JSONL format (one JSON object per line)
export def to-jsonl []: list -> string {
  let input = $in
  if ($input | is-empty) {
    return ""
  }
  $input | each {|row| $row | to json --raw } | str join "\n"
}

# Convert JSONL string to a list of records
export def from-jsonl []: string -> list {
  let input = $in | str trim
  if ($input | is-empty) {
    return []
  }
  $input | lines | where {|line| ($line | str trim | is-not-empty) } | each {|line| $line | from json }
}

# =============================================================================
# Sync Directory
# =============================================================================

# Get the default sync directory path
export def get-sync-dir []: nothing -> string {
  let data_home = ($env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share"))
  $data_home | path join "c5t" "sync"
}

# =============================================================================
# Sync File Operations
# =============================================================================

# Write sync data to JSONL files
export def write-sync-files [sync_dir: string data: record] {
  # Ensure sync directory exists
  mkdir $sync_dir

  # Write each entity type to its own file
  if ($data.repos | is-not-empty) {
    $data.repos | to-jsonl | save -f ($sync_dir | path join "repos.jsonl")
  } else {
    "" | save -f ($sync_dir | path join "repos.jsonl")
  }

  if ($data.lists | is-not-empty) {
    $data.lists | to-jsonl | save -f ($sync_dir | path join "lists.jsonl")
  } else {
    "" | save -f ($sync_dir | path join "lists.jsonl")
  }

  if ($data.tasks | is-not-empty) {
    $data.tasks | to-jsonl | save -f ($sync_dir | path join "tasks.jsonl")
  } else {
    "" | save -f ($sync_dir | path join "tasks.jsonl")
  }

  if ($data.notes | is-not-empty) {
    $data.notes | to-jsonl | save -f ($sync_dir | path join "notes.jsonl")
  } else {
    "" | save -f ($sync_dir | path join "notes.jsonl")
  }
}

# Read sync data from JSONL files
export def read-sync-files [sync_dir: string]: nothing -> record {
  let repos_file = ($sync_dir | path join "repos.jsonl")
  let lists_file = ($sync_dir | path join "lists.jsonl")
  let tasks_file = ($sync_dir | path join "tasks.jsonl")
  let notes_file = ($sync_dir | path join "notes.jsonl")

  let repos = if ($repos_file | path exists) {
    open $repos_file | from-jsonl
  } else {
    []
  }

  let lists = if ($lists_file | path exists) {
    open $lists_file | from-jsonl
  } else {
    []
  }

  let tasks = if ($tasks_file | path exists) {
    open $tasks_file | from-jsonl
  } else {
    []
  }

  let notes = if ($notes_file | path exists) {
    open $notes_file | from-jsonl
  } else {
    []
  }

  {repos: $repos lists: $lists tasks: $tasks notes: $notes}
}

# =============================================================================
# Sync Import/Export
# =============================================================================

# Export database to sync files
export def export-db-to-sync [sync_dir: string] {
  use storage.nu [ export-data ]

  let result = export-data

  if not $result.success {
    return {success: false error: $result.error}
  }

  # Write to sync files
  write-sync-files $sync_dir $result.data

  {
    success: true
    repos: ($result.data.repos | length)
    lists: ($result.data.lists | length)
    tasks: ($result.data.tasks | length)
    notes: ($result.data.notes | length)
  }
}

# Import sync files to database (last-write-wins via updated_at/last_accessed_at)
export def import-sync-to-db [sync_dir: string] {
  use storage.nu [ get-db-path execute-sql query-sql ]

  let data = read-sync-files $sync_dir

  if ($data.repos | is-empty) and ($data.lists | is-empty) and ($data.tasks | is-empty) and ($data.notes | is-empty) {
    return {success: true message: "No sync data to import"}
  }

  let db_path = get-db-path

  # Import repos (upsert with last-write-wins)
  for repo in $data.repos {
    let existing = (query-sql $db_path "SELECT id, last_accessed_at FROM repo WHERE id = ?" [$repo.id])

    if $existing.success and ($existing.data | length) > 0 {
      # Update if sync data is newer
      let existing_time = $existing.data.0.last_accessed_at
      if $repo.last_accessed_at > $existing_time {
        execute-sql $db_path "UPDATE repo SET remote = ?, path = ?, last_accessed_at = ? WHERE id = ?" [
          $repo.remote
          $repo.path
          $repo.last_accessed_at
          $repo.id
        ]
      }
    } else {
      # Insert new repo
      execute-sql $db_path "INSERT INTO repo (id, remote, path, created_at, last_accessed_at) VALUES (?, ?, ?, ?, ?)" [
        $repo.id
        $repo.remote
        $repo.path
        $repo.created_at
        $repo.last_accessed_at
      ]
    }
  }

  # Import lists (upsert with last-write-wins)
  for list in $data.lists {
    let existing = (query-sql $db_path "SELECT id, updated_at FROM task_list WHERE id = ?" [$list.id])

    if $existing.success and ($existing.data | length) > 0 {
      # Update if sync data is newer
      let existing_time = $existing.data.0.updated_at
      if $list.updated_at > $existing_time {
        execute-sql $db_path "UPDATE task_list SET repo_id = ?, name = ?, description = ?, notes = ?, tags = ?, status = ?, external_ref = ?, updated_at = ?, archived_at = ? WHERE id = ?" [
          $list.repo_id
          $list.name
          $list.description
          $list.notes
          $list.tags
          $list.status
          (if "external_ref" in $list { $list.external_ref } else { null })
          $list.updated_at
          $list.archived_at
          $list.id
        ]
      }
    } else {
      # Insert new list
      execute-sql $db_path "INSERT INTO task_list (id, repo_id, name, description, notes, tags, status, external_ref, created_at, updated_at, archived_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)" [
        $list.id
        $list.repo_id
        $list.name
        $list.description
        $list.notes
        $list.tags
        $list.status
        (if "external_ref" in $list { $list.external_ref } else { null })
        $list.created_at
        $list.updated_at
        $list.archived_at
      ]
    }
  }

  # Import tasks (upsert - tasks don't have updated_at, use completed_at or created_at)
  for task in $data.tasks {
    let existing = (query-sql $db_path "SELECT id FROM task WHERE id = ?" [$task.id])

    if $existing.success and ($existing.data | length) > 0 {
      # Update existing task
      execute-sql $db_path "UPDATE task SET list_id = ?, parent_id = ?, content = ?, status = ?, priority = ?, started_at = ?, completed_at = ? WHERE id = ?" [
        $task.list_id
        $task.parent_id
        $task.content
        $task.status
        $task.priority
        $task.started_at
        $task.completed_at
        $task.id
      ]
    } else {
      # Insert new task
      execute-sql $db_path "INSERT INTO task (id, list_id, parent_id, content, status, priority, created_at, started_at, completed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)" [
        $task.id
        $task.list_id
        $task.parent_id
        $task.content
        $task.status
        $task.priority
        $task.created_at
        $task.started_at
        $task.completed_at
      ]
    }
  }

  # Import notes (upsert with last-write-wins)
  for note in $data.notes {
    let existing = (query-sql $db_path "SELECT id, updated_at FROM note WHERE id = ?" [$note.id])

    if $existing.success and ($existing.data | length) > 0 {
      # Update if sync data is newer
      let existing_time = $existing.data.0.updated_at
      if $note.updated_at > $existing_time {
        execute-sql $db_path "UPDATE note SET repo_id = ?, title = ?, content = ?, tags = ?, note_type = ?, updated_at = ? WHERE id = ?" [
          $note.repo_id
          $note.title
          $note.content
          $note.tags
          $note.note_type
          $note.updated_at
          $note.id
        ]
      }
    } else {
      # Insert new note
      execute-sql $db_path "INSERT INTO note (id, repo_id, title, content, tags, note_type, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)" [
        $note.id
        $note.repo_id
        $note.title
        $note.content
        $note.tags
        $note.note_type
        $note.created_at
        $note.updated_at
      ]
    }
  }

  {
    success: true
    repos: ($data.repos | length)
    lists: ($data.lists | length)
    tasks: ($data.tasks | length)
    notes: ($data.notes | length)
  }
}
