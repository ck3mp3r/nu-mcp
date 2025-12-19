# SQLite database operations for c5t tool

# Wrapper for query db - can be mocked in tests
# Exported so tests can override it
export def run-query-db [db_path: string sql: string params: list = []] {
  open $db_path | query db $sql -p $params
}

# Get XDG data directory for c5t
export def get-xdg-data-path [] {
  let xdg_data = if "XDG_DATA_HOME" in $env and $env.XDG_DATA_HOME != null and ($env.XDG_DATA_HOME | str length) > 0 {
    $env.XDG_DATA_HOME
  } else {
    $"($env.HOME)/.local/share"
  }
  $"($xdg_data)/c5t"
}

export def get-db-path [] {
  let db_dir = get-xdg-data-path

  if not ($db_dir | path exists) {
    mkdir $db_dir
  }

  $"($db_dir)/context.db"
}

# Parse git remote URL into normalized format: "host:org/repo"
# Supports: https://github.com/org/repo.git, git@github.com:org/repo.git
export def parse-git-remote [url: string] {
  let cleaned = $url | str trim | str replace -r '\.git$' ''

  # SSH format: git@github.com:org/repo
  if ($cleaned | str starts-with "git@") {
    let parts = $cleaned | str replace "git@" "" | split row ":"
    let host = $parts | first | str replace ".com" ""
    let path = $parts | skip 1 | str join ":"
    return $"($host):($path)"
  }

  # HTTPS format: https://github.com/org/repo
  if ($cleaned | str contains "://") {
    let without_proto = $cleaned | split row "://" | last
    let parts = $without_proto | split row "/"
    let host = $parts | first | str replace ".com" ""
    let path = $parts | skip 1 | str join "/"
    return $"($host):($path)"
  }

  # Unknown format - return as-is
  $cleaned
}

# Get git remote URL for a directory (defaults to CWD)
export def get-git-remote [path?: string] {
  try {
    let url = if $path != null {
      git -C $path remote get-url origin | str trim
    } else {
      git remote get-url origin | str trim
    }
    {success: true url: $url}
  } catch {
    {success: false error: "Not a git repository or no remote 'origin' configured"}
  }
}

# Get existing repo record, returns {success: bool, repo_id?: string, exists: bool}
export def get-repo [remote: string] {
  let db_path = init-database

  let sql = "SELECT id, remote, path FROM repo WHERE remote = ?"
  let result = query-sql $db_path $sql [$remote]

  if $result.success and ($result.data | length) > 0 {
    # Update last_accessed_at
    let update_sql = "UPDATE repo SET last_accessed_at = datetime('now') WHERE id = ?"
    let _ = execute-sql $db_path $update_sql [$result.data.0.id]
    return {success: true exists: true repo_id: ($result.data.0.id)}
  }

  {success: true exists: false}
}

# Create a new repo record
export def create-repo [remote: string path: string] {
  use utils.nu [ generate-id ]

  let db_path = init-database
  let id = generate-id

  let insert_sql = "INSERT INTO repo (id, remote, path) VALUES (?, ?, ?)"
  let insert_result = execute-sql $db_path $insert_sql [$id $remote $path]

  if $insert_result.success {
    {success: true repo_id: $id created: true}
  } else {
    {success: false error: "Failed to create repo"}
  }
}

# Update an existing repo's path
export def update-repo-path [repo_id: string path: string] {
  let db_path = init-database

  let sql = "UPDATE repo SET path = ?, last_accessed_at = datetime('now') WHERE id = ?"
  let result = execute-sql $db_path $sql [$path $repo_id]

  if $result.success {
    {success: true}
  } else {
    {success: false error: "Failed to update repo path"}
  }
}

# Upsert repo - create if not exists, update path if exists
# path: optional path to git repo (defaults to CWD)
export def upsert-repo [path?: string] {
  # Resolve the path - if provided, use it; otherwise use CWD
  let resolved_path = if $path != null {
    # Resolve relative paths to absolute
    $path | path expand
  } else {
    $env.PWD
  }

  let git_result = get-git-remote (if $path != null { $resolved_path } else { null })

  if not $git_result.success {
    return {success: false error: $git_result.error}
  }

  let remote = parse-git-remote $git_result.url

  let existing = get-repo $remote

  if not $existing.success {
    return $existing
  }

  if $existing.exists {
    # Update path
    let update_result = update-repo-path $existing.repo_id $resolved_path
    if not $update_result.success {
      return $update_result
    }
    {success: true created: false repo_id: $existing.repo_id remote: $remote path: $resolved_path}
  } else {
    # Create new
    let create_result = create-repo $remote $resolved_path
    if not $create_result.success {
      return $create_result
    }
    {success: true created: true repo_id: $create_result.repo_id remote: $remote path: $resolved_path}
  }
}

# Get the last-accessed repository (most recently used)
export def get-last-accessed-repo [] {
  let db_path = init-database

  let sql = "SELECT id, remote, path FROM repo ORDER BY last_accessed_at DESC LIMIT 1"
  let result = query-sql $db_path $sql []

  if not $result.success {
    return {success: false error: $"Failed to get last-accessed repo: ($result.error)"}
  }

  if ($result.data | is-empty) {
    return {success: false error: "No repositories registered. Use upsert_repo to register a repository first."}
  }

  {success: true repo_id: $result.data.0.id remote: $result.data.0.remote}
}

# Get repo ID - uses explicit repo_id if provided, otherwise resolves from CWD git repo
# repo_id: optional explicit repo ID to use
# Errors if CWD is not a git repo or not registered (no implicit fallback)
export def get-current-repo-id [repo_id?: string] {
  # If explicit repo_id provided, use it
  if $repo_id != null {
    return {success: true repo_id: $repo_id}
  }

  # Try to get from CWD git remote
  let git_result = get-git-remote

  if not $git_result.success {
    # Not in a git repo - error, don't fall back
    return {
      success: false
      error: "Not in a git repository.\n\nEither:\n  1. Run from within a git repository, or\n  2. Provide an explicit repo_id parameter\n\nUse list_repos to see available repositories."
    }
  }

  let remote = parse-git-remote $git_result.url
  let existing = get-repo $remote

  if not $existing.success {
    return $existing
  }

  if $existing.exists {
    return {success: true repo_id: $existing.repo_id}
  }

  # CWD is a git repo but not registered
  {
    success: false
    error: $"Repository not registered: ($remote)\n\nUse upsert_repo to register this repository first."
  }
}

# List all known repositories
export def list-repos [] {
  let db_path = init-database

  let sql = "SELECT id, remote, path, created_at, last_accessed_at 
             FROM repo 
             ORDER BY last_accessed_at DESC"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get repositories: ($result.error)"
    }
  }

  {
    success: true
    repos: $result.data
    count: ($result.data | length)
  }
}

export def init-database [] {
  let db_path = get-db-path

  if not ($db_path | path exists) {
    create-schema $db_path
  }

  $db_path
}

export def run-migrations [] {
  let db_path = get-db-path
  create-schema $db_path
  $db_path
}

const SQL_DIR = (path self sql)

def get-migration-files [] {
  glob $"($SQL_DIR)/*.sql" | sort
}

def get-migration-version [filepath: string] {
  $filepath | path basename | split row "_" | first
}

def migration-applied [db_path: string version: string] {
  try {
    let result = sqlite3 -json $db_path $"SELECT version FROM schema_migrations WHERE version = '($version)';"

    if ($result | str trim | is-empty) {
      false
    } else {
      let parsed = $result | from json
      ($parsed | length) > 0
    }
  } catch {
    false
  }
}

def record-migration [db_path: string version: string] {
  sqlite3 $db_path $"INSERT OR IGNORE INTO schema_migrations \(version\) VALUES \('($version)'\);"
}

def create-schema [db_path: string] {
  let migrations_table_sql = "CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
  );"
  sqlite3 $db_path $migrations_table_sql

  let migrations = get-migration-files

  for migration in $migrations {
    let version = get-migration-version $migration

    if not (migration-applied $db_path $version) {
      # Read SQL file content and pipe to sqlite3 via stdin
      let sql_content = open $migration
      $sql_content | sqlite3 $db_path
      record-migration $db_path $version
    }
  }
}

export def execute-sql [db_path: string sql: string params: list = []] {
  try {
    run-query-db $db_path $sql $params
    {success: true output: ""}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

def query-sql [db_path: string sql: string params: list = []] {
  try {
    let result = run-query-db $db_path $sql $params
    {success: true data: $result}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

def parse-tags [tags_json: any] {
  if $tags_json != null and $tags_json != "" {
    try { $tags_json | from json } catch { [] }
  } else {
    []
  }
}

# ============================================================================
# TASK LIST FUNCTIONS
# ============================================================================

# Create a task list
export def create-task-list [
  name: string
  description?: string
  tags?: list
  explicit_repo_id?: string
] {
  use utils.nu [ generate-id ]

  let db_path = init-database

  let repo_result = get-current-repo-id $explicit_repo_id

  if not $repo_result.success {
    return {
      success: false
      error: $"Failed to get repository: ($repo_result.error? | default 'unknown')"
    }
  }

  let repo_id = $repo_result.repo_id
  let id = generate-id

  let tags_json = if $tags != null and ($tags | is-not-empty) {
    $tags | to json --raw
  } else {
    null
  }

  let desc_value = if $description != null { $description } else { null }

  let sql = "INSERT INTO task_list (id, repo_id, name, description, tags) 
             VALUES (?, ?, ?, ?, ?)"

  let params = [$id $repo_id $name $desc_value $tags_json]

  let result = execute-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to create task list: ($result.error)"
    }
  }

  {
    success: true
    id: $id
    repo_id: $repo_id
    name: $name
    description: $description
    tags: $tags
  }
}

# Get task lists with status filter
export def get-task-lists [
  --status: string = "active" # active, archived, or all
  --tags: list = []
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  # Build WHERE clauses
  mut where_clauses = []

  # Status filter
  if $status != "all" {
    $where_clauses = ($where_clauses | append $"status = '($status)'")
  }

  # Repo filter
  if not $all_repos {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $where_clauses = ($where_clauses | append $"repo_id = '($repo_result.repo_id)'")
  }

  let where_sql = if ($where_clauses | is-not-empty) {
    "WHERE " + ($where_clauses | str join " AND ")
  } else {
    ""
  }

  let sql = $"SELECT id, repo_id, name, description, notes, tags, status, created_at, updated_at, archived_at 
              FROM task_list 
              ($where_sql)
              ORDER BY created_at DESC"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get task lists: ($result.error)"
    }
  }

  let results = $result.data

  # Filter by tags if specified
  let filtered = if ($tags | is-not-empty) {
    $results | where {|row|
      let row_tags = parse-tags $row.tags
      ($tags | any {|tag| $tag in $row_tags })
    }
  } else {
    $results
  }

  # Parse tags for each list
  let parsed = if ($filtered | is-empty) {
    []
  } else {
    $filtered | each {|row|
      $row | upsert tags (parse-tags $row.tags)
    }
  }

  {
    success: true
    lists: $parsed
    count: ($parsed | length)
  }
}

# Get list metadata without tasks
export def get-list [
  list_id: string
] {
  let db_path = init-database

  let sql = "SELECT id, repo_id, name, description, notes, tags, status, created_at, updated_at, archived_at 
             FROM task_list 
             WHERE id = ?"
  let params = [$list_id]

  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to get list: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  let list = $result.data | first | upsert tags (parse-tags ($result.data | first | get tags))

  {
    success: true
    list: $list
  }
}

# Check if a list exists
export def list-exists [
  list_id: string
] {
  let db_path = get-db-path

  let sql = "SELECT id FROM task_list WHERE id = ?"
  let params = [$list_id]

  let result = query-sql $db_path $sql $params

  $result.success and (not ($result.data | is-empty))
}

# Upsert a task list - create if no list_id, update if list_id provided
export def upsert-list [
  list_id?: string
  name?: string
  description?: string
  tags?: list
  notes?: string
  repo_id?: string
] {
  let db_path = init-database

  if $list_id != null {
    # Update existing
    if not (list-exists $list_id) {
      return {
        success: false
        error: $"List not found: ($list_id)"
      }
    }

    if $name == null and $description == null and $tags == null and $notes == null {
      return {
        success: false
        error: "At least one of 'name', 'description', 'tags', or 'notes' must be provided for update"
      }
    }

    if $name != null and ($name | str trim | is-empty) {
      return {
        success: false
        error: "Name cannot be empty"
      }
    }

    mut set_clauses = []
    mut params = []

    if $name != null {
      $set_clauses = ($set_clauses | append "name = ?")
      $params = ($params | append $name)
    }

    if $description != null {
      $set_clauses = ($set_clauses | append "description = ?")
      $params = ($params | append $description)
    }

    if $tags != null {
      $set_clauses = ($set_clauses | append "tags = ?")
      $params = ($params | append ($tags | to json))
    }

    if $notes != null {
      $set_clauses = ($set_clauses | append "notes = ?")
      $params = ($params | append $notes)
    }

    $set_clauses = ($set_clauses | append "updated_at = datetime('now')")

    let set_sql = $set_clauses | str join ", "
    let sql = $"UPDATE task_list SET ($set_sql) WHERE id = ?"
    $params = ($params | append $list_id)

    let result = execute-sql $db_path $sql $params

    if not $result.success {
      return {
        success: false
        error: $"Failed to update list: ($result.error)"
      }
    }

    let updated = get-list $list_id
    {
      success: true
      created: false
      list: $updated.list
    }
  } else {
    # Create new
    if $name == null {
      return {
        success: false
        error: "'name' is required when creating a new list"
      }
    }

    if ($name | str trim | is-empty) {
      return {
        success: false
        error: "Name cannot be empty"
      }
    }

    let result = create-task-list $name $description $tags $repo_id

    if not $result.success {
      return $result
    }

    if $notes != null {
      let _ = update-list-notes $result.id $notes
    }

    {
      success: true
      created: true
      id: $result.id
      list_id: $result.id
      repo_id: $result.repo_id
      name: $name
      description: $description
      tags: $tags
      notes: $notes
      list: {
        id: $result.id
        repo_id: $result.repo_id
        name: $name
        description: $description
        tags: $tags
        notes: $notes
      }
    }
  }
}

# Update notes on a task list
export def update-list-notes [
  list_id: string
  notes: string
] {
  let db_path = get-db-path

  let sql = "UPDATE task_list 
             SET notes = ? 
             WHERE id = ?"

  let params = [$notes $list_id]
  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to update notes: ($result.error)"
    }
  }
}

# Delete a task list (optionally with force to delete tasks too)
export def delete-list [
  list_id: string
  force: bool = false
] {
  let db_path = get-db-path

  if not (list-exists $list_id) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  if not $force {
    let count_sql = "SELECT COUNT(*) as count FROM task WHERE list_id = ?"
    let count_result = query-sql $db_path $count_sql [$list_id]

    if $count_result.success and ($count_result.data | is-not-empty) {
      let task_count = $count_result.data | first | get count
      if $task_count > 0 {
        return {
          success: false
          error: $"List has tasks \(($task_count)\). Use force=true to delete list and all tasks."
        }
      }
    }
  }

  if $force {
    let delete_tasks_sql = "DELETE FROM task WHERE list_id = ?"
    let tasks_result = execute-sql $db_path $delete_tasks_sql [$list_id]

    if not $tasks_result.success {
      return {
        success: false
        error: $"Failed to delete tasks: ($tasks_result.error)"
      }
    }
  }

  let sql = "DELETE FROM task_list WHERE id = ?"
  let params = [$list_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to delete list: ($result.error)"
    }
  }
}

# ============================================================================
# TASK FUNCTIONS
# ============================================================================

# Add a task to a list
export def add-task [
  list_id: string
  content: string
  priority?: int
  status?: string
] {
  use utils.nu [ generate-id ]

  let db_path = get-db-path
  let id = generate-id

  let task_status = if $status != null { $status } else { "backlog" }
  let priority_value = if $priority != null { $priority } else { null }

  let sql = "INSERT INTO task (id, list_id, content, status, priority) 
             VALUES (?, ?, ?, ?, ?)"

  let params = [$id $list_id $content $task_status $priority_value]

  let result = execute-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to add task: ($result.error)"
    }
  }

  {
    success: true
    id: $id
    list_id: $list_id
    content: $content
    status: $task_status
    priority: $priority
  }
}

# Add a subtask with parent_id
export def add-subtask [
  list_id: string
  parent_id: string
  content: string
  priority?: int
  status?: string
] {
  use utils.nu [ generate-id ]

  let db_path = get-db-path
  let id = generate-id

  let task_status = if $status != null { $status } else { "backlog" }
  let priority_value = if $priority != null { $priority } else { null }

  let sql = "INSERT INTO task (id, list_id, parent_id, content, status, priority) 
             VALUES (?, ?, ?, ?, ?, ?)"

  let params = [$id $list_id $parent_id $content $task_status $priority_value]

  let result = execute-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to add subtask: ($result.error)"
    }
  }

  {
    success: true
    id: $id
    parent_id: $parent_id
    list_id: $list_id
    content: $content
    status: $task_status
    priority: $priority
  }
}

# Get a single task
export def get-task [
  list_id: string
  task_id: string
] {
  let db_path = get-db-path

  let sql = "SELECT id, list_id, parent_id, content, status, priority, created_at, started_at, completed_at 
             FROM task 
             WHERE id = ? AND list_id = ?"

  let params = [$task_id $list_id]

  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to get task: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: $"Task not found: ($task_id)"
    }
  }

  {
    success: true
    task: ($result.data | first)
  }
}

# Get subtasks for a parent task
export def get-subtasks [
  list_id: string
  parent_id: string
] {
  let db_path = get-db-path

  let sql = "SELECT id, list_id, parent_id, content, status, priority, created_at, started_at, completed_at 
             FROM task 
             WHERE list_id = ? AND parent_id = ?
             ORDER BY created_at ASC"

  let params = [$list_id $parent_id]

  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to get subtasks: ($result.error)"
    }
  }

  {
    success: true
    tasks: $result.data
    count: ($result.data | length)
  }
}

# Check if a task exists
export def task-exists [
  list_id: string
  task_id: string
] {
  let db_path = get-db-path

  let sql = "SELECT id FROM task WHERE id = ? AND list_id = ?"
  let params = [$task_id $list_id]

  let result = query-sql $db_path $sql $params

  $result.success and (not ($result.data | is-empty))
}

# Delete a task
export def delete-task [
  list_id: string
  task_id: string
] {
  let db_path = get-db-path

  let check = get-task $list_id $task_id
  if not $check.success {
    return $check
  }

  let sql = "DELETE FROM task WHERE id = ? AND list_id = ?"
  let params = [$task_id $list_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to delete task: ($result.error)"
    }
  }
}

# Upsert a task - create if no task_id, update if task_id provided
export def upsert-task [
  list_id: string
  task_id?: string
  content?: string
  priority?: int
  status?: string
  parent_id?: string
] {
  let db_path = get-db-path

  if not (list-exists $list_id) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  if $task_id != null {
    # Update existing
    if not (task-exists $list_id $task_id) {
      return {
        success: false
        error: $"Task not found: ($task_id)"
      }
    }

    if $content == null and $priority == null and $status == null {
      return {
        success: false
        error: "At least one of 'content', 'priority', or 'status' must be provided for update"
      }
    }

    if $content != null and ($content | str trim | is-empty) {
      return {
        success: false
        error: "Content cannot be empty"
      }
    }

    mut set_clauses = []
    mut params = []

    if $content != null {
      $set_clauses = ($set_clauses | append "content = ?")
      $params = ($params | append $content)
    }

    if $priority != null {
      $set_clauses = ($set_clauses | append "priority = ?")
      $params = ($params | append $priority)
    }

    if $status != null {
      $set_clauses = ($set_clauses | append "status = ?")
      $params = ($params | append $status)

      # Handle timestamp updates for status changes
      if $status == "in_progress" {
        $set_clauses = ($set_clauses | append "started_at = COALESCE(started_at, datetime('now'))")
      }
      if $status in ["done" "cancelled"] {
        $set_clauses = ($set_clauses | append "completed_at = datetime('now')")
      }
    }

    let set_sql = $set_clauses | str join ", "
    let sql = $"UPDATE task SET ($set_sql) WHERE id = ? AND list_id = ?"
    $params = ($params | append $task_id)
    $params = ($params | append $list_id)

    let result = execute-sql $db_path $sql $params

    if not $result.success {
      return {
        success: false
        error: $"Failed to update task: ($result.error)"
      }
    }

    let updated = get-task $list_id $task_id

    {
      success: true
      created: false
      task: $updated.task
    }
  } else {
    # Create new
    if $content == null {
      return {
        success: false
        error: "'content' is required when creating a new task"
      }
    }

    if ($content | str trim | is-empty) {
      return {
        success: false
        error: "Content cannot be empty"
      }
    }

    # Use add-subtask if parent_id is provided, otherwise add-task
    let result = if $parent_id != null {
      add-subtask $list_id $parent_id $content $priority $status
    } else {
      add-task $list_id $content $priority $status
    }

    if not $result.success {
      return $result
    }

    {
      success: true
      created: true
      id: $result.id
      task_id: $result.id
      list_id: $list_id
      content: $content
      priority: $priority
      status: ($status | default "backlog")
      parent_id: $parent_id
      task: {
        id: $result.id
        list_id: $list_id
        content: $content
        priority: $priority
        status: ($status | default "backlog")
        parent_id: $parent_id
      }
    }
  }
}

# Complete a task (set status to done)
export def complete-task [
  list_id: string
  task_id: string
] {
  let db_path = get-db-path

  if not (task-exists $list_id $task_id) {
    return {
      success: false
      error: $"Task not found: ($task_id)"
    }
  }

  let sql = "UPDATE task SET status = 'done', completed_at = datetime('now') WHERE id = ? AND list_id = ?"
  let params = [$task_id $list_id]

  let result = execute-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to complete task: ($result.error)"
    }
  }

  let updated = get-task $list_id $task_id
  {
    success: true
    task: $updated.task
  }
}

# Move a task from one list to another
export def move-task [
  source_list_id: string
  task_id: string
  target_list_id: string
] {
  let db_path = get-db-path

  if not (task-exists $source_list_id $task_id) {
    return {
      success: false
      error: $"Task not found: ($task_id) in list ($source_list_id)"
    }
  }

  if not (list-exists $target_list_id) {
    return {
      success: false
      error: $"Target list not found: ($target_list_id)"
    }
  }

  let sql = "UPDATE task SET list_id = ? WHERE id = ? AND list_id = ?"
  let params = [$target_list_id $task_id $source_list_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to move task: ($result.error)"
    }
  }
}

# Get a list with its tasks
export def get-list-with-tasks [
  list_id: string
  status_filter?: list
] {
  let db_path = init-database

  let list_sql = "SELECT id, repo_id, name, description, notes, tags, created_at, updated_at 
                   FROM task_list 
                   WHERE id = ?"

  let list_result = query-sql $db_path $list_sql [$list_id]

  if not $list_result.success {
    return {
      success: false
      error: $"Failed to get list: ($list_result.error)"
    }
  }

  if ($list_result.data | is-empty) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  let list = $list_result.data | first | upsert tags (parse-tags ($list_result.data | first | get tags))

  # Get tasks with optional status filter (array of statuses)
  let tasks_sql = if $status_filter != null and ($status_filter | is-not-empty) {
    let status_list = $status_filter | each {|s| $"'($s)'" } | str join ", "
    $"SELECT id, list_id, parent_id, content, status, priority, created_at, started_at, completed_at 
      FROM task 
      WHERE list_id = ? AND status IN \(($status_list)\) 
      ORDER BY 
        CASE status 
          WHEN 'backlog' THEN 1 
          WHEN 'todo' THEN 2 
          WHEN 'in_progress' THEN 3 
          WHEN 'review' THEN 4 
          WHEN 'done' THEN 5 
          WHEN 'cancelled' THEN 6 
        END,
        priority DESC NULLS LAST, 
        created_at ASC"
  } else {
    "SELECT id, list_id, parent_id, content, status, priority, created_at, started_at, completed_at 
      FROM task 
      WHERE list_id = ? 
      ORDER BY 
        CASE status 
          WHEN 'backlog' THEN 1 
          WHEN 'todo' THEN 2 
          WHEN 'in_progress' THEN 3 
          WHEN 'review' THEN 4 
          WHEN 'done' THEN 5 
          WHEN 'cancelled' THEN 6 
        END,
        priority DESC NULLS LAST, 
        created_at ASC"
  }

  let tasks_result = query-sql $db_path $tasks_sql [$list_id]

  if not $tasks_result.success {
    return {
      success: false
      error: $"Failed to get tasks: ($tasks_result.error)"
    }
  }

  {
    success: true
    list: $list
    tasks: $tasks_result.data
    count: ($tasks_result.data | length)
  }
}

# Get active lists with task counts by status for summary
export def get-task-lists-with-counts [
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  let repo_filter = if $all_repos {
    ""
  } else {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $" AND tl.repo_id = '($repo_result.repo_id)'"
  }

  let sql = $"SELECT 
               tl.id,
               tl.repo_id,
               tl.name,
               tl.description,
               tl.tags,
               COUNT\(CASE WHEN t.status = 'backlog' THEN 1 END\) as backlog_count,
               COUNT\(CASE WHEN t.status = 'todo' THEN 1 END\) as todo_count,
               COUNT\(CASE WHEN t.status = 'in_progress' THEN 1 END\) as in_progress_count,
               COUNT\(CASE WHEN t.status = 'review' THEN 1 END\) as review_count,
               COUNT\(CASE WHEN t.status = 'done' THEN 1 END\) as done_count,
               COUNT\(CASE WHEN t.status = 'cancelled' THEN 1 END\) as cancelled_count,
               COUNT\(t.id\) as total_count
             FROM task_list tl
             LEFT JOIN task t ON tl.id = t.list_id
             WHERE tl.status = 'active'($repo_filter)
             GROUP BY tl.id
             ORDER BY tl.created_at DESC"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get task lists with counts: ($result.error)"
    }
  }

  let parsed = $result.data | each {|row|
      $row | upsert tags (parse-tags $row.tags)
    }

  {
    success: true
    lists: $parsed
    count: ($parsed | length)
  }
}

# Get all in-progress tasks across all lists for summary
export def get-all-in-progress-tasks [
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  let repo_filter = if $all_repos {
    ""
  } else {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $" AND tl.repo_id = '($repo_result.repo_id)'"
  }

  let sql = $"SELECT 
               t.id,
               t.list_id,
               t.content,
               t.priority,
               t.started_at,
               tl.name as list_name
             FROM task t
             JOIN task_list tl ON t.list_id = tl.id
             WHERE t.status = 'in_progress'
             AND tl.status = 'active'($repo_filter)
             ORDER BY t.priority DESC NULLS LAST, t.started_at ASC"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get in-progress tasks: ($result.error)"
    }
  }

  {
    success: true
    tasks: $result.data
    count: ($result.data | length)
  }
}

# Get recently completed tasks for summary
export def get-recently-completed-tasks [
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  let repo_filter = if $all_repos {
    ""
  } else {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $" AND tl.repo_id = '($repo_result.repo_id)'"
  }

  let sql = $"SELECT 
               t.id,
               t.list_id,
               t.content,
               t.status,
               t.priority,
               t.completed_at,
               tl.name as list_name
             FROM task t
             JOIN task_list tl ON t.list_id = tl.id
             WHERE t.status IN \('done', 'cancelled'\)
             AND tl.status = 'active'($repo_filter)
             AND t.completed_at IS NOT NULL
             ORDER BY t.completed_at DESC
             LIMIT 20"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get recently completed tasks: ($result.error)"
    }
  }

  {
    success: true
    tasks: $result.data
    count: ($result.data | length)
  }
}

# Get high-priority pending tasks for summary
export def get-high-priority-tasks [
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  let repo_filter = if $all_repos {
    ""
  } else {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $" AND tl.repo_id = '($repo_result.repo_id)'"
  }

  let sql = $"SELECT 
               t.id,
               t.list_id,
               t.content,
               t.status,
               t.priority,
               tl.name as list_name
             FROM task t
             JOIN task_list tl ON t.list_id = tl.id
             WHERE t.status IN \('backlog', 'todo'\)
             AND tl.status = 'active'($repo_filter)
             AND t.priority >= 4
             ORDER BY t.priority DESC, t.created_at ASC
             LIMIT 10"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get high-priority tasks: ($result.error)"
    }
  }

  {
    success: true
    tasks: $result.data
    count: ($result.data | length)
  }
}

# Get comprehensive summary/overview for quick status at-a-glance
export def get-summary [
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  let repo_filter = if $all_repos {
    ""
  } else {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $" AND tl.repo_id = '($repo_result.repo_id)'"
  }

  let stats_sql = $"SELECT 
                     COUNT\(DISTINCT tl.id\) as active_lists,
                     COUNT\(CASE WHEN t.status = 'backlog' THEN 1 END\) as backlog_total,
                     COUNT\(CASE WHEN t.status = 'todo' THEN 1 END\) as todo_total,
                     COUNT\(CASE WHEN t.status = 'in_progress' THEN 1 END\) as in_progress_total,
                     COUNT\(CASE WHEN t.status = 'review' THEN 1 END\) as review_total,
                     COUNT\(CASE WHEN t.status = 'done' THEN 1 END\) as done_total,
                     COUNT\(CASE WHEN t.status = 'cancelled' THEN 1 END\) as cancelled_total,
                     COUNT\(t.id\) as total_tasks
                   FROM task_list tl
                   LEFT JOIN task t ON tl.id = t.list_id
                   WHERE tl.status = 'active'($repo_filter)"

  let stats_result = query-sql $db_path $stats_sql []

  if not $stats_result.success {
    return {
      success: false
      error: $"Failed to get summary stats: ($stats_result.error)"
    }
  }

  let stats = if ($stats_result.data | is-empty) {
    {
      active_lists: 0
      backlog_total: 0
      todo_total: 0
      in_progress_total: 0
      review_total: 0
      done_total: 0
      cancelled_total: 0
      total_tasks: 0
    }
  } else {
    $stats_result.data | first
  }

  let lists_result = if $all_repos {
    get-task-lists-with-counts --all-repos
  } else {
    get-task-lists-with-counts
  }

  if not $lists_result.success {
    return {
      success: false
      error: $"Failed to get active lists: ($lists_result.error)"
    }
  }

  let in_progress_result = if $all_repos {
    get-all-in-progress-tasks --all-repos
  } else {
    get-all-in-progress-tasks
  }

  if not $in_progress_result.success {
    return {
      success: false
      error: $"Failed to get in-progress tasks: ($in_progress_result.error)"
    }
  }

  let priority_result = if $all_repos {
    get-high-priority-tasks --all-repos
  } else {
    get-high-priority-tasks
  }

  if not $priority_result.success {
    return {
      success: false
      error: $"Failed to get high-priority tasks: ($priority_result.error)"
    }
  }

  let completed_result = if $all_repos {
    get-recently-completed-tasks --all-repos
  } else {
    get-recently-completed-tasks
  }

  if not $completed_result.success {
    return {
      success: false
      error: $"Failed to get completed tasks: ($completed_result.error)"
    }
  }

  {
    success: true
    summary: {
      stats: $stats
      active_lists: $lists_result.lists
      in_progress: $in_progress_result.tasks
      high_priority: $priority_result.tasks
      recently_completed: $completed_result.tasks
    }
  }
}

# ============================================================================
# NOTE FUNCTIONS
# ============================================================================

# Create a standalone note
export def create-note [
  title: string
  content: string
  tags?: list
  explicit_repo_id?: string
] {
  use utils.nu [ generate-id ]

  let db_path = init-database
  let id = generate-id

  let repo_result = get-current-repo-id $explicit_repo_id

  if not $repo_result.success {
    return {
      success: false
      error: $"Failed to get repository: ($repo_result.error? | default 'unknown')"
    }
  }

  let repo_id = $repo_result.repo_id

  let tags_value = if $tags != null and ($tags | is-not-empty) {
    $tags | to json --raw
  } else {
    null
  }

  let sql = "INSERT INTO note (id, repo_id, title, content, tags, note_type) 
             VALUES (?, ?, ?, ?, ?, ?)"

  let params = [$id $repo_id $title $content $tags_value "manual"]
  let result = execute-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to create note: ($result.error)"
    }
  }

  {
    success: true
    id: $id
    repo_id: $repo_id
    title: $title
    tags: $tags
  }
}

# Get notes with optional filtering
export def get-notes [
  tag_filter?: list
  note_type?: string
  limit?: int
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  mut where_clauses = []

  if not $all_repos {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $where_clauses = ($where_clauses | append $"repo_id = '($repo_result.repo_id)'")
  }

  if $note_type != null {
    $where_clauses = ($where_clauses | append $"note_type = '($note_type)'")
  }

  let where_sql = if ($where_clauses | is-not-empty) {
    "WHERE " + ($where_clauses | str join " AND ")
  } else {
    ""
  }

  let limit_sql = if $limit != null {
    $"LIMIT ($limit)"
  } else {
    ""
  }

  let sql = $"SELECT id, repo_id, title, content, tags, note_type, created_at, updated_at 
             FROM note 
             ($where_sql)
             ORDER BY created_at DESC 
             ($limit_sql);"

  let result = query-sql $db_path $sql []

  if not $result.success {
    return {
      success: false
      error: $"Failed to get notes: ($result.error)"
    }
  }

  let results = $result.data

  let filtered = if $tag_filter != null and ($tag_filter | is-not-empty) {
    $results | where {|row|
      let row_tags = parse-tags $row.tags
      ($tag_filter | any {|tag| $tag in $row_tags })
    }
  } else {
    $results
  }

  let parsed = if ($filtered | is-empty) {
    []
  } else {
    $filtered | each {|row|
      $row | upsert tags (parse-tags $row.tags)
    }
  }

  {
    success: true
    notes: $parsed
    count: ($parsed | length)
  }
}

# Get a specific note by ID
export def get-note [
  note_id: string
] {
  let db_path = get-db-path

  let sql = "SELECT id, repo_id, title, content, tags, note_type, created_at, updated_at 
             FROM note 
             WHERE id = ?"

  let result = query-sql $db_path $sql [$note_id]

  if not $result.success {
    return {
      success: false
      error: $"Failed to get note: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: $"Note not found: ($note_id)"
    }
  }

  let note = $result.data | first | upsert tags (parse-tags ($result.data | first | get tags))

  {
    success: true
    note: $note
  }
}

# Upsert a note - create if no note_id, update if note_id provided
export def upsert-note [
  note_id?: string
  title?: string
  content?: string
  tags?: list
  repo_id?: string
] {
  let db_path = init-database

  if $note_id != null {
    let existing = get-note $note_id
    if not $existing.success {
      return $existing
    }

    if $title == null and $content == null and $tags == null {
      return {
        success: false
        error: "At least one of 'title', 'content', or 'tags' must be provided for update"
      }
    }

    mut set_clauses = []
    mut params = []

    if $title != null {
      $set_clauses = ($set_clauses | append "title = ?")
      $params = ($params | append $title)
    }

    if $content != null {
      $set_clauses = ($set_clauses | append "content = ?")
      $params = ($params | append $content)
    }

    if $tags != null {
      $set_clauses = ($set_clauses | append "tags = ?")
      $params = ($params | append ($tags | to json))
    }

    $set_clauses = ($set_clauses | append "updated_at = datetime('now')")

    let set_sql = $set_clauses | str join ", "
    let sql = $"UPDATE note SET ($set_sql) WHERE id = ?"
    $params = ($params | append $note_id)

    let result = execute-sql $db_path $sql $params

    if not $result.success {
      return {
        success: false
        error: $"Failed to update note: ($result.error)"
      }
    }

    let updated = get-note $note_id
    {
      success: true
      created: false
      note: $updated.note
    }
  } else {
    if $title == null or $content == null {
      return {
        success: false
        error: "Both 'title' and 'content' are required when creating a new note"
      }
    }

    let result = create-note $title $content $tags $repo_id

    if not $result.success {
      return $result
    }

    {
      success: true
      created: true
      id: $result.id
      note_id: $result.id
      repo_id: $result.repo_id
      title: $title
      tags: $tags
      note: {
        id: $result.id
        repo_id: $result.repo_id
        title: $title
      }
    }
  }
}

# Delete a note by ID
export def delete-note [
  note_id: string
] {
  let db_path = get-db-path

  let check_sql = "SELECT id FROM note WHERE id = ?"
  let check_result = query-sql $db_path $check_sql [$note_id]

  if not $check_result.success {
    return {
      success: false
      error: $"Failed to check note: ($check_result.error)"
    }
  }

  if ($check_result.data | is-empty) {
    return {
      success: false
      error: $"Note not found: ($note_id)"
    }
  }

  let sql = "DELETE FROM note WHERE id = ?"
  let params = [$note_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to delete note: ($result.error)"
    }
  }
}

# Search notes using FTS5 full-text search
export def search-notes [
  query: string
  --limit: int = 10
  --tags: list = []
  --all-repos
  --repo-id: string
] {
  let db_path = init-database

  let repo_filter = if $all_repos {
    ""
  } else {
    let repo_result = get-current-repo-id $repo_id
    if not $repo_result.success {
      return {
        success: false
        error: $"Failed to get current repository: ($repo_result.error? | default 'unknown')"
      }
    }
    $" AND note.repo_id = '($repo_result.repo_id)'"
  }

  let sql = $"SELECT 
               note.id, 
               note.repo_id,
               note.title, 
               note.content, 
               note.tags, 
               note.note_type,
               note.created_at,
               bm25\(note_fts\) as rank
             FROM note_fts
             JOIN note ON note.rowid = note_fts.rowid
             WHERE note_fts MATCH ?($repo_filter)
             ORDER BY rank
             LIMIT ?"

  let params = [$query $limit]
  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Search failed: ($result.error)"
    }
  }

  let parsed = $result.data | each {|note|
      $note | upsert tags (parse-tags ($note | get tags))
    }

  let filtered = if ($tags | is-not-empty) {
    $parsed | where {|note|
      let note_tags = $note.tags
      $tags | any {|tag| $tag in $note_tags }
    }
  } else {
    $parsed
  }

  {
    success: true
    notes: $filtered
    count: ($filtered | length)
  }
}

# ============================================================================
# EXPORT/IMPORT FUNCTIONS
# ============================================================================

# Export all data as JSON for backup (v2.0 format with repos)
export def export-data [] {
  let db_path = get-db-path

  # Get all repos
  let repos_sql = "SELECT id, remote, path, created_at, last_accessed_at 
                   FROM repo 
                   ORDER BY id"
  let repos_result = query-sql $db_path $repos_sql []

  if not $repos_result.success {
    return {
      success: false
      error: $"Failed to export repos: ($repos_result.error)"
    }
  }

  # Get all lists
  let lists_sql = "SELECT id, repo_id, name, description, notes, tags, status, created_at, updated_at, archived_at 
                   FROM task_list 
                   ORDER BY id"
  let lists_result = query-sql $db_path $lists_sql []

  if not $lists_result.success {
    return {
      success: false
      error: $"Failed to export lists: ($lists_result.error)"
    }
  }

  # Get all tasks
  let tasks_sql = "SELECT id, list_id, parent_id, content, status, priority, created_at, started_at, completed_at 
                   FROM task 
                   ORDER BY list_id, id"
  let tasks_result = query-sql $db_path $tasks_sql []

  if not $tasks_result.success {
    return {
      success: false
      error: $"Failed to export tasks: ($tasks_result.error)"
    }
  }

  # Get all notes (no source_id)
  let notes_sql = "SELECT id, repo_id, title, content, tags, note_type, created_at, updated_at 
                   FROM note 
                   ORDER BY id"
  let notes_result = query-sql $db_path $notes_sql []

  if not $notes_result.success {
    return {
      success: false
      error: $"Failed to export notes: ($notes_result.error)"
    }
  }

  {
    success: true
    data: {
      version: "2.0"
      exported_at: (date now | format date "%Y-%m-%dT%H:%M:%S")
      repos: $repos_result.data
      lists: $lists_result.data
      tasks: $tasks_result.data
      notes: $notes_result.data
    }
  }
}

# Import data from JSON backup (v2.0 format - requires repos)
export def import-data [
  data: record
] {
  let db_path = get-db-path

  # Validate v2.0 format - must have repos
  if "repos" not-in $data {
    return {
      success: false
      error: "Invalid data format: missing 'repos' field. This import requires v2.0 format with repos."
    }
  }

  if "lists" not-in $data {
    return {
      success: false
      error: "Invalid data: missing 'lists' field"
    }
  }

  if "tasks" not-in $data {
    return {
      success: false
      error: "Invalid data: missing 'tasks' field"
    }
  }

  if "notes" not-in $data {
    return {
      success: false
      error: "Invalid data: missing 'notes' field"
    }
  }

  # Clear existing data (full restore)
  let _ = execute-sql $db_path "DELETE FROM task" []
  let _ = execute-sql $db_path "DELETE FROM task_list" []
  let _ = execute-sql $db_path "DELETE FROM note" []
  let _ = execute-sql $db_path "DELETE FROM repo" []

  # Track ID mappings
  mut repo_id_map = {}
  mut list_id_map = {}
  mut task_id_map = {}
  mut imported_repos = 0
  mut imported_lists = 0
  mut imported_tasks = 0
  mut imported_notes = 0

  # Import repos
  for repo in $data.repos {
    let sql = "INSERT INTO repo (remote, path, created_at, last_accessed_at) 
               VALUES (?, ?, ?, ?) 
               RETURNING id"
    let params = [
      $repo.remote
      ($repo.path? | default null)
      ($repo.created_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($repo.last_accessed_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
    ]

    let result = query-sql $db_path $sql $params
    if $result.success and ($result.data | is-not-empty) {
      let new_id = $result.data | first | get id
      $repo_id_map = ($repo_id_map | upsert ($repo.id | into string) $new_id)
      $imported_repos = $imported_repos + 1
    }
  }

  # Import lists
  for list in $data.lists {
    let old_repo_id = $list.repo_id | into string
    let new_repo_id = if $old_repo_id in $repo_id_map {
      $repo_id_map | get $old_repo_id
    } else {
      continue
    }

    let tags_json = if $list.tags != null { $list.tags } else { null }
    let sql = "INSERT INTO task_list (repo_id, name, description, notes, tags, status, created_at, updated_at, archived_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) 
               RETURNING id"
    let params = [
      $new_repo_id
      $list.name
      ($list.description? | default null)
      ($list.notes? | default null)
      $tags_json
      ($list.status? | default "active")
      ($list.created_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($list.updated_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($list.archived_at? | default null)
    ]

    let result = query-sql $db_path $sql $params
    if $result.success and ($result.data | is-not-empty) {
      let new_id = $result.data | first | get id
      $list_id_map = ($list_id_map | upsert ($list.id | into string) $new_id)
      $imported_lists = $imported_lists + 1
    }
  }

  # Import tasks (first pass - root tasks without parent_id)
  for task in $data.tasks {
    if $task.parent_id? != null {
      continue # Skip subtasks for now
    }

    let old_list_id = $task.list_id | into string
    let new_list_id = if $old_list_id in $list_id_map {
      $list_id_map | get $old_list_id
    } else {
      continue
    }

    let sql = "INSERT INTO task (list_id, parent_id, content, status, priority, created_at, started_at, completed_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               RETURNING id"
    let params = [
      $new_list_id
      null
      $task.content
      ($task.status? | default "backlog")
      ($task.priority? | default null)
      ($task.created_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($task.started_at? | default null)
      ($task.completed_at? | default null)
    ]

    let result = query-sql $db_path $sql $params
    if $result.success and ($result.data | is-not-empty) {
      let new_id = $result.data | first | get id
      $task_id_map = ($task_id_map | upsert ($task.id | into string) $new_id)
      $imported_tasks = $imported_tasks + 1
    }
  }

  # Import tasks (second pass - subtasks with parent_id)
  for task in $data.tasks {
    if $task.parent_id? == null {
      continue # Skip root tasks
    }

    let old_list_id = $task.list_id | into string
    let new_list_id = if $old_list_id in $list_id_map {
      $list_id_map | get $old_list_id
    } else {
      continue
    }

    let old_parent_id = $task.parent_id | into string
    let new_parent_id = if $old_parent_id in $task_id_map {
      $task_id_map | get $old_parent_id
    } else {
      continue
    }

    let sql = "INSERT INTO task (list_id, parent_id, content, status, priority, created_at, started_at, completed_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    let params = [
      $new_list_id
      $new_parent_id
      $task.content
      ($task.status? | default "backlog")
      ($task.priority? | default null)
      ($task.created_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($task.started_at? | default null)
      ($task.completed_at? | default null)
    ]

    let result = execute-sql $db_path $sql $params
    if $result.success {
      $imported_tasks = $imported_tasks + 1
    }
  }

  # Import notes
  for note in $data.notes {
    let old_repo_id = $note.repo_id | into string
    let new_repo_id = if $old_repo_id in $repo_id_map {
      $repo_id_map | get $old_repo_id
    } else {
      continue
    }

    let tags_json = if ($note.tags? | default null) != null { $note.tags } else { null }
    let sql = "INSERT INTO note (repo_id, title, content, tags, note_type, created_at, updated_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?)"
    let params = [
      $new_repo_id
      $note.title
      $note.content
      $tags_json
      ($note.note_type? | default "manual")
      ($note.created_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($note.updated_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
    ]

    let result = execute-sql $db_path $sql $params
    if $result.success {
      $imported_notes = $imported_notes + 1
    }
  }

  {
    success: true
    imported: {
      repos: $imported_repos
      lists: $imported_lists
      tasks: $imported_tasks
      notes: $imported_notes
    }
  }
}
