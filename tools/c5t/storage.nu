# SQLite database operations for c5t tool

export def get-db-path [] {
  let db_dir = ".c5t"

  if not ($db_dir | path exists) {
    mkdir $db_dir
  }

  $"($db_dir)/context.db"
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

def get-migration-files [] {
  let sql_dir = "tools/c5t/sql"
  glob $"($sql_dir)/*.sql" | sort
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

def execute-sql [db_path: string sql: string] {
  try {
    sqlite3 $db_path $sql
    {success: true output: ""}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

def query-sql [db_path: string sql: string] {
  try {
    let result = sqlite3 -json $db_path $sql | from json
    {success: true data: $result}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

export def create-todo-list [
  name: string
  description?: string
  tags?: list
] {
  let db_path = get-db-path

  use utils.nu generate-id
  let id = generate-id

  let tags_json = if $tags != null and ($tags | is-not-empty) {
    $tags | to json --raw
  } else {
    "null"
  }

  let escaped_name = $name | str replace --all "'" "''"
  let desc_value = if $description != null {
    let escaped_desc = $description | str replace --all "'" "''"
    $"'($escaped_desc)'"
  } else {
    "null"
  }

  let sql = $"INSERT INTO todo_list \(id, name, description, tags\) 
             VALUES \('($id)', '($escaped_name)', ($desc_value), '($tags_json)'\);"

  let result = execute-sql $db_path $sql

  if $result.success {
    {
      success: true
      id: $id
      name: $name
      description: $description
      tags: $tags
    }
  } else {
    {
      success: false
      error: $"Failed to create todo list: ($result.error)"
    }
  }
}

def parse-tags [tags_json: any] {
  if $tags_json != null and $tags_json != "" {
    try { $tags_json | from json } catch { [] }
  } else {
    []
  }
}

export def get-active-lists [
  tag_filter?: list
] {
  let db_path = get-db-path

  let sql = "SELECT id, name, description, notes, tags, created_at, updated_at 
             FROM todo_list 
             WHERE status = 'active' 
             ORDER BY created_at DESC;"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get active lists: ($result.error)"
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

  let parsed = $filtered | each {|row|
    $row | upsert tags (parse-tags $row.tags)
  }

  {
    success: true
    lists: $parsed
    count: ($parsed | length)
  }
}

# Add a todo item to a list
export def add-todo-item [
  list_id: string
  content: string
  priority?: int
  status?: string
] {
  let db_path = get-db-path

  use utils.nu generate-id
  let id = generate-id

  # Default status is 'backlog'
  let item_status = if $status != null { $status } else { "backlog" }

  let escaped_content = $content | str replace --all "'" "''"
  let priority_value = if $priority != null { $priority } else { "null" }

  let sql = $"INSERT INTO todo_item \(id, list_id, content, status, priority\) 
             VALUES \('($id)', '($list_id)', '($escaped_content)', '($item_status)', ($priority_value)\);"

  let result = execute-sql $db_path $sql

  if $result.success {
    {
      success: true
      id: $id
      list_id: $list_id
      content: $content
      status: $item_status
      priority: $priority
    }
  } else {
    {
      success: false
      error: $"Failed to add todo item: ($result.error)"
    }
  }
}

# Update item status with timestamp automation
export def update-item-status [
  list_id: string
  item_id: string
  new_status: string
] {
  let db_path = get-db-path

  # Get current status for timestamp logic
  let current_item = get-item $list_id $item_id
  if not $current_item.success {
    return $current_item
  }

  let old_status = $current_item.item.status

  # Build timestamp updates based on status transition
  mut timestamp_updates = []

  # Moving to in_progress: set started_at if null
  if $new_status == "in_progress" {
    $timestamp_updates = ($timestamp_updates | append "started_at = COALESCE(started_at, datetime('now'))")
  }

  # Moving to done/cancelled: set completed_at
  if $new_status in ["done" "cancelled"] {
    $timestamp_updates = ($timestamp_updates | append "completed_at = datetime('now')")
  }

  # Moving back from done/cancelled: clear timestamps
  if $old_status in ["done" "cancelled"] and $new_status in ["backlog" "todo"] {
    $timestamp_updates = ($timestamp_updates | append "started_at = NULL")
    $timestamp_updates = ($timestamp_updates | append "completed_at = NULL")
  } else if $old_status == "in_progress" and $new_status in ["backlog" "todo"] {
    $timestamp_updates = ($timestamp_updates | append "started_at = NULL")
  }

  # Build SQL with timestamp updates
  let timestamp_sql = if ($timestamp_updates | is-not-empty) {
    ", " + ($timestamp_updates | str join ", ")
  } else {
    ""
  }

  let sql = $"UPDATE todo_item 
             SET status = '($new_status)'($timestamp_sql) 
             WHERE id = '($item_id)' AND list_id = '($list_id)';"

  let result = execute-sql $db_path $sql

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to update item status: ($result.error)"
    }
  }
}

# Update item priority
export def update-item-priority [
  list_id: string
  item_id: string
  priority: int
] {
  let db_path = get-db-path

  let priority_value = if $priority != null { $priority } else { "null" }

  let sql = $"UPDATE todo_item 
             SET priority = ($priority_value) 
             WHERE id = '($item_id)' AND list_id = '($list_id)';"

  let result = execute-sql $db_path $sql

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to update item priority: ($result.error)"
    }
  }
}

# Get a list with its items
export def get-list-with-items [
  list_id: string
  status_filter?: string
] {
  let db_path = get-db-path

  # Get the list
  let list_sql = $"SELECT id, name, description, tags, created_at, updated_at 
                   FROM todo_list 
                   WHERE id = '($list_id)';"

  let list_result = query-sql $db_path $list_sql

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

  # Get items with optional status filter
  let items_sql = if $status_filter != null and $status_filter == "active" {
    # Active filter: exclude done and cancelled
    $"SELECT id, list_id, content, status, priority, position, created_at, started_at, completed_at 
      FROM todo_item 
      WHERE list_id = '($list_id)' AND status NOT IN \('done', 'cancelled'\) 
      ORDER BY priority DESC NULLS LAST, created_at ASC;"
  } else if $status_filter != null {
    # Specific status filter
    $"SELECT id, list_id, content, status, priority, position, created_at, started_at, completed_at 
      FROM todo_item 
      WHERE list_id = '($list_id)' AND status = '($status_filter)' 
      ORDER BY priority DESC NULLS LAST, created_at ASC;"
  } else {
    # No filter: get all items
    $"SELECT id, list_id, content, status, priority, position, created_at, started_at, completed_at 
      FROM todo_item 
      WHERE list_id = '($list_id)' 
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
        created_at ASC;"
  }

  let items_result = query-sql $db_path $items_sql

  if not $items_result.success {
    return {
      success: false
      error: $"Failed to get items: ($items_result.error)"
    }
  }

  {
    success: true
    list: $list
    items: $items_result.data
    count: ($items_result.data | length)
  }
}

# Get a single item
export def get-item [
  list_id: string
  item_id: string
] {
  let db_path = get-db-path

  let sql = $"SELECT id, list_id, content, status, priority, position, created_at, started_at, completed_at 
             FROM todo_item 
             WHERE id = '($item_id)' AND list_id = '($list_id)';"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get item: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: $"Item not found: ($item_id)"
    }
  }

  {
    success: true
    item: ($result.data | first)
  }
}

# Check if a list exists
export def list-exists [
  list_id: string
] {
  let db_path = get-db-path

  let sql = $"SELECT id FROM todo_list WHERE id = '($list_id)';"

  let result = query-sql $db_path $sql

  $result.success and (not ($result.data | is-empty))
}

# Check if an item exists
export def item-exists [
  list_id: string
  item_id: string
] {
  let db_path = get-db-path

  let sql = $"SELECT id FROM todo_item WHERE id = '($item_id)' AND list_id = '($list_id)';"

  let result = query-sql $db_path $sql

  $result.success and (not ($result.data | is-empty))
}

# Update notes on a todo list
export def update-todo-notes [
  list_id: string
  notes: string
] {
  let db_path = get-db-path

  let escaped_notes = $notes | str replace --all "'" "''"

  let sql = $"UPDATE todo_list 
             SET notes = '($escaped_notes)' 
             WHERE id = '($list_id)';"

  let result = execute-sql $db_path $sql

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to update notes: ($result.error)"
    }
  }
}
