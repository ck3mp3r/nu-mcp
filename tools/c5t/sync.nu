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

# =============================================================================
# MCP Sync Functions
# =============================================================================

# Initialize sync by setting up git repository in sync directory
# Returns: {success: bool, message: string, error?: string}
export def sync-init [remote_url: any]: nothing -> record<success: bool, message: string> {
  let sync_dir = get-sync-dir

  # Check if already initialized
  if (is-git-repo $sync_dir) {
    return {success: false error: "Sync is already initialized. Use sync_status to check configuration."}
  }

  # Create sync directory and initialize git
  mkdir $sync_dir
  cd $sync_dir
  ^git init --quiet

  # Add remote if provided
  if $remote_url != null and ($remote_url | str length) > 0 {
    ^git remote add origin $remote_url
  }

  cd -

  let remote_msg = if $remote_url != null and ($remote_url | str length) > 0 {
    $"\n  Remote: ($remote_url)"
  } else {
    "\n  No remote configured. Add one with: git -C ~/.local/share/c5t/sync remote add origin <url>"
  }

  {
    success: true
    message: $"✓ Sync initialized at ($sync_dir)($remote_msg)"
  }
}

# Get sync status information
# Returns: {success: bool, message: string}
export def sync-status []: nothing -> record<success: bool, message: string> {
  let sync_dir = get-sync-dir

  # Check if sync is configured
  if not (is-git-repo $sync_dir) {
    return {
      success: true
      message: "Sync is not configured.

To set up sync:
  1. Use sync_init to create the sync repository
  2. Optionally add a remote: git -C ~/.local/share/c5t/sync remote add origin <url>
  3. Use sync_export to push your data
  4. Use sync_refresh to pull changes"
    }
  }

  # Get remote info
  cd $sync_dir
  let remotes = try {
    ^git remote -v | str trim
  } catch {
    ""
  }

  let status = try {
    ^git status --short | str trim
  } catch {
    ""
  }

  let has_remote = ($remotes | is-not-empty)
  let is_clean = ($status | is-empty)

  cd -

  # Check sync files
  let repos_file = ($sync_dir | path join "repos.jsonl")
  let lists_file = ($sync_dir | path join "lists.jsonl")
  let tasks_file = ($sync_dir | path join "tasks.jsonl")
  let notes_file = ($sync_dir | path join "notes.jsonl")

  let has_files = ($repos_file | path exists) or ($lists_file | path exists) or ($tasks_file | path exists) or ($notes_file | path exists)

  mut lines = ["Sync is configured."]
  $lines = ($lines | append $"  Directory: ($sync_dir)")

  if $has_remote {
    $lines = ($lines | append "  Remotes:")
    let remote_lines = ($remotes | lines | each {|r| $"    ($r)" })
    $lines = ($lines | append $remote_lines)
  } else {
    $lines = ($lines | append "  No remote configured.")
  }

  $lines = ($lines | append $"  Working tree: (if $is_clean { 'clean' } else { 'dirty' })")
  $lines = ($lines | append $"  Sync files: (if $has_files { 'present' } else { 'not created yet' })")

  {
    success: true
    message: ($lines | str join (char newline))
  }
}

# Refresh local database from sync files (pull + import)
# Returns: {success: bool, message: string, error?: string}
export def sync-refresh []: nothing -> record<success: bool, message: string> {
  use storage.nu [ init-database ]

  let sync_dir = get-sync-dir

  # Check if sync is configured
  if not (is-git-repo $sync_dir) {
    return {
      success: true
      message: "Sync is not configured. Use sync_init first."
    }
  }

  # Check if working tree is clean
  if not (git-status-clean $sync_dir) {
    return {
      success: true
      message: "Warning: Sync directory has uncommitted changes. Skipping pull.

Resolve conflicts manually and run sync_refresh again."
    }
  }

  # Try to pull (may fail if no remote or no commits yet)
  let pull_result = git-pull $sync_dir

  # Initialize database schema if needed
  init-database

  # Import sync files
  let import_result = import-sync-to-db $sync_dir

  let message = if $import_result.success {
    let pull_msg = if $pull_result.success {
      $pull_result.message
    } else {
      "No remote to pull from"
    }

    if $import_result.message? != null and $import_result.message == "No sync data to import" {
      $"✓ Sync refreshed (no data to import)
  Pull: ($pull_msg)"
    } else {
      $"✓ Sync refreshed
  Pull: ($pull_msg)
  Imported: ($import_result.repos) repos, ($import_result.lists) lists, ($import_result.tasks) tasks, ($import_result.notes) notes"
    }
  } else {
    $"Error during import: ($import_result.error? | default 'unknown')"
  }

  {
    success: true
    message: $message
  }
}

# Export local database to sync files and push to remote
# Returns: {success: bool, message: string, error?: string}
export def sync-export [commit_message: any]: nothing -> record<success: bool, message: string> {
  let sync_dir = get-sync-dir

  # Check if sync is configured
  if not (is-git-repo $sync_dir) {
    return {
      success: false
      error: "Sync is not configured. Use sync_init first."
    }
  }

  # Try to pull first (get latest before export)
  let pull_result = git-pull $sync_dir

  # Export database to sync files
  let export_result = export-db-to-sync $sync_dir

  if not $export_result.success {
    return {
      success: false
      error: $"Export failed: ($export_result.error? | default 'unknown')"
    }
  }

  # Generate commit message
  let timestamp = date now | format date "%Y-%m-%d %H:%M:%S"
  let message = if $commit_message != null and ($commit_message | str length) > 0 {
    $commit_message
  } else {
    $"c5t sync: ($timestamp)"
  }

  # Commit and push
  let commit_result = git-commit-push $sync_dir $message

  let push_status = if $commit_result.success {
    if $commit_result.message == "Nothing to commit" {
      "No changes to commit"
    } else {
      "Committed and pushed"
    }
  } else {
    $"Commit/push failed: ($commit_result.message)"
  }

  {
    success: true
    message: $"✓ Sync exported
  Exported: ($export_result.repos) repos, ($export_result.lists) lists, ($export_result.tasks) tasks, ($export_result.notes) notes
  Status: ($push_status)"
  }
}
