# SQLite database operations for c5t tool

# Wrapper for query db - can be mocked in tests
def run-query-db [db_path: string sql: string params: list = []] {
  open $db_path | query db $sql -p $params
}

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

def execute-sql [db_path: string sql: string params: list = []] {
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

export def create-todo-list [
  name: string
  description?: string
  tags?: list
] {
  let db_path = get-db-path

  let tags_json = if $tags != null and ($tags | is-not-empty) {
    $tags | to json --raw
  } else {
    null
  }

  let desc_value = if $description != null {
    $description
  } else {
    null
  }

  # Use INSERT ... RETURNING with parameters
  let sql = "INSERT INTO todo_list (name, description, tags) 
             VALUES (?, ?, ?) 
             RETURNING id"

  let params = [$name $desc_value $tags_json]

  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to create todo list: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: "Failed to retrieve inserted ID"
    }
  }

  let list_id = $result.data.0.id

  {
    success: true
    id: $list_id
    name: $name
    description: $description
    tags: $tags
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

# Add a todo item to a list
export def add-todo-item [
  list_id: int
  content: string
  priority?: int
  status?: string
] {
  let db_path = get-db-path

  # Default status is 'backlog'
  let item_status = if $status != null { $status } else { "backlog" }

  let priority_value = if $priority != null { $priority } else { null }

  # Use INSERT ... RETURNING with parameters
  let sql = "INSERT INTO todo_item (list_id, content, status, priority) 
             VALUES (?, ?, ?, ?) 
             RETURNING id"

  let params = [$list_id $content $item_status $priority_value]

  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to add todo item: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: "Failed to retrieve inserted item ID"
    }
  }

  let item_id = $result.data.0.id

  {
    success: true
    id: $item_id
    list_id: $list_id
    content: $content
    status: $item_status
    priority: $priority
  }
}

# Update item status with timestamp automation
export def update-item-status [
  list_id: int
  item_id: int
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

  # Build SQL with timestamp updates (still need dynamic SQL here)
  let timestamp_sql = if ($timestamp_updates | is-not-empty) {
    ", " + ($timestamp_updates | str join ", ")
  } else {
    ""
  }

  let sql = $"UPDATE todo_item 
             SET status = ?($timestamp_sql) 
             WHERE id = ? AND list_id = ?"

  let params = [$new_status $item_id $list_id]
  let result = execute-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to update item status: ($result.error)"
    }
  }

  # Check if all items are now completed and auto-archive if so
  if $new_status in ["done" "cancelled"] {
    if (all-items-completed $list_id) {
      let archive_result = archive-todo-list $list_id
      if $archive_result.success {
        return {
          success: true
          archived: true
          note_id: $archive_result.note_id
        }
      }
    }
  }

  {success: true archived: false}
}

# Update item priority
export def update-item-priority [
  list_id: int
  item_id: int
  priority: int
] {
  let db_path = get-db-path

  let priority_value = if $priority != null { $priority } else { null }

  let sql = "UPDATE todo_item 
             SET priority = ? 
             WHERE id = ? AND list_id = ?"

  let params = [$priority_value $item_id $list_id]
  let result = execute-sql $db_path $sql $params

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
  list_id: int
  status_filter?: string
] {
  let db_path = get-db-path

  # Get the list
  let list_sql = $"SELECT id, name, description, notes, tags, created_at, updated_at 
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
  list_id: int
  item_id: int
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
  list_id: int
] {
  let db_path = get-db-path

  let sql = $"SELECT id FROM todo_list WHERE id = '($list_id)';"

  let result = query-sql $db_path $sql

  $result.success and (not ($result.data | is-empty))
}

# Check if an item exists
export def item-exists [
  list_id: int
  item_id: int
] {
  let db_path = get-db-path

  let sql = $"SELECT id FROM todo_item WHERE id = '($item_id)' AND list_id = '($list_id)';"

  let result = query-sql $db_path $sql

  $result.success and (not ($result.data | is-empty))
}

# Update notes on a todo list
export def update-todo-notes [
  list_id: int
  notes: string
] {
  let db_path = get-db-path

  let sql = "UPDATE todo_list 
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

# Generate markdown content for archived todo list
export def generate-archive-note [
  todo_list: record
  items: list
] {
  mut lines = [
    $"# ($todo_list.name)"
    ""
  ]

  # Add description if present
  if $todo_list.description != null and $todo_list.description != "" {
    $lines = ($lines | append $todo_list.description)
    $lines = ($lines | append "")
  }

  # Add completed items section
  $lines = ($lines | append "## Completed Items")
  $lines = ($lines | append "")

  let completed_items = $items | where status in ["done" "cancelled"]

  if ($completed_items | is-empty) {
    $lines = ($lines | append "No items were completed.")
  } else {
    for item in $completed_items {
      let status_emoji = if $item.status == "done" { "✅" } else { "❌" }
      let timestamp = if $item.completed_at != null {
        $" \(completed: ($item.completed_at)\)"
      } else {
        ""
      }
      $lines = ($lines | append $"- ($status_emoji) ($item.content)($timestamp)")
    }
  }

  $lines = ($lines | append "")

  # Add progress notes if present
  if $todo_list.notes != null and $todo_list.notes != "" {
    $lines = ($lines | append "## Progress Notes")
    $lines = ($lines | append "")
    $lines = ($lines | append $todo_list.notes)
    $lines = ($lines | append "")
  }

  # Add archive footer
  $lines = ($lines | append "---")
  $lines = ($lines | append $"*Auto-archived on (date now | format date '%Y-%m-%d %H:%M:%S')*")

  $lines | str join (char newline)
}

# Check if all items in a list are completed
export def all-items-completed [
  list_id: int
] {
  let db_path = get-db-path

  # Get count of non-completed items
  let sql = $"SELECT COUNT\(*\) as count 
             FROM todo_item 
             WHERE list_id = '($list_id)' 
             AND status NOT IN \('done', 'cancelled'\);"

  let result = query-sql $db_path $sql

  if not $result.success {
    return false
  }

  if ($result.data | is-empty) {
    return false
  }

  let count = $result.data | first | get count

  $count == 0
}

# Archive a todo list as a note
export def archive-todo-list [
  list_id: int
] {
  let db_path = get-db-path

  # Get the list with items
  let list_data = get-list-with-items $list_id

  if not $list_data.success {
    return {
      success: false
      error: $"Failed to get list data: ($list_data.error)"
    }
  }

  # Generate archive note content
  let note_content = generate-archive-note $list_data.list $list_data.items

  # Create note with parameters
  let tags_value = if $list_data.list.tags != null and ($list_data.list.tags | is-not-empty) {
    $list_data.list.tags | to json --raw
  } else {
    null
  }

  let insert_note_sql = "INSERT INTO note (title, content, tags, note_type, source_id) 
                         VALUES (?, ?, ?, ?, ?) 
                         RETURNING id"

  let params = [$list_data.list.name $note_content $tags_value "archived_todo" $list_id]
  let note_result = query-sql $db_path $insert_note_sql $params

  if not $note_result.success {
    return {
      success: false
      error: $"Failed to create archive note: ($note_result.error)"
    }
  }

  if ($note_result.data | is-empty) {
    return {
      success: false
      error: "Failed to retrieve archive note ID"
    }
  }

  let note_id = $note_result.data.0.id

  # Update list status to archived with parameters
  let archive_list_sql = "UPDATE todo_list 
                           SET status = 'archived', archived_at = datetime('now') 
                           WHERE id = ?"

  let archive_params = [$list_id]
  let archive_result = execute-sql $db_path $archive_list_sql $archive_params

  if not $archive_result.success {
    return {
      success: false
      error: $"Failed to archive list: ($archive_result.error)"
    }
  }

  {
    success: true
    note_id: $note_id
    list_id: $list_id
  }
}

# Create a standalone note
export def create-note [
  title: string
  content: string
  tags?: list
] {
  let db_path = get-db-path

  let tags_value = if $tags != null and ($tags | is-not-empty) {
    $tags | to json --raw
  } else {
    null
  }

  let sql = "INSERT INTO note (title, content, tags, note_type) 
             VALUES (?, ?, ?, ?) 
             RETURNING id"

  let params = [$title $content $tags_value "manual"]
  let result = query-sql $db_path $sql $params

  if not $result.success {
    return {
      success: false
      error: $"Failed to create note: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: false
      error: "Failed to retrieve note ID"
    }
  }

  let note_id = $result.data.0.id

  {
    success: true
    id: $note_id
    title: $title
    tags: $tags
  }
}

# Get notes with optional filtering
export def get-notes [
  tag_filter?: list
  note_type?: string
  limit?: int
] {
  let db_path = get-db-path

  # Build WHERE clauses
  mut where_clauses = []

  if $note_type != null {
    $where_clauses = ($where_clauses | append $"note_type = '($note_type)'")
  } else {
    # By default, exclude scratchpad from list
    $where_clauses = ($where_clauses | append "note_type != 'scratchpad'")
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

  let sql = $"SELECT id, title, content, tags, note_type, source_id, created_at, updated_at 
             FROM note 
             ($where_sql)
             ORDER BY created_at DESC 
             ($limit_sql);"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get notes: ($result.error)"
    }
  }

  let results = $result.data

  # Filter by tags if specified
  let filtered = if $tag_filter != null and ($tag_filter | is-not-empty) {
    $results | where {|row|
      let row_tags = parse-tags $row.tags
      ($tag_filter | any {|tag| $tag in $row_tags })
    }
  } else {
    $results
  }

  # Parse tags for each note
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
export def get-note-by-id [
  note_id: int
] {
  let db_path = get-db-path

  let sql = $"SELECT id, title, content, tags, note_type, source_id, created_at, updated_at 
             FROM note 
             WHERE id = '($note_id)';"

  let result = query-sql $db_path $sql

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

# Search notes using FTS5 full-text search
export def search-notes [
  query: string
  --limit: int = 10
  --tags: list = []
] {
  let db_path = get-db-path

  # FTS5 search query with bm25 ranking using parameters
  let sql = "SELECT 
               note.id, 
               note.title, 
               note.content, 
               note.tags, 
               note.note_type,
               note.created_at,
               bm25(note_fts) as rank
             FROM note_fts
             JOIN note ON note.id = note_fts.rowid
             WHERE note_fts MATCH ?
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

  # Parse tags for each note
  let parsed = $result.data | each {|note|
      $note | upsert tags (parse-tags ($note | get tags))
    }

  # Filter by tags if specified (client-side filtering)
  let filtered = if ($tags | is-not-empty) {
    $parsed | where {|note|
      let note_tags = $note.tags
      # Check if any of the filter tags are in the note's tags
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

# Update or create scratchpad note
# Only one scratchpad note should exist - UPDATE if exists, INSERT if not
export def update-scratchpad [
  content: string
] {
  let db_path = get-db-path

  # Check if scratchpad exists
  let check_sql = "SELECT id FROM note WHERE note_type = 'scratchpad' LIMIT 1"
  let check_result = query-sql $db_path $check_sql

  if not $check_result.success {
    return {
      success: false
      error: $"Failed to check scratchpad: ($check_result.error)"
    }
  }

  if ($check_result.data | is-empty) {
    # CREATE new scratchpad with parameters
    let insert_sql = "INSERT INTO note (title, content, note_type) 
                      VALUES (?, ?, ?) 
                      RETURNING id"

    let params = ["Scratchpad" $content "scratchpad"]
    let insert_result = query-sql $db_path $insert_sql $params

    if not $insert_result.success {
      return {
        success: false
        error: $"Failed to create scratchpad: ($insert_result.error)"
      }
    }

    if ($insert_result.data | is-empty) {
      return {
        success: false
        error: "Failed to retrieve scratchpad ID"
      }
    }

    let scratchpad_id = $insert_result.data.0.id

    {
      success: true
      scratchpad_id: $scratchpad_id
    }
  } else {
    # UPDATE existing scratchpad with parameters
    let scratchpad_id = $check_result.data | first | get id
    let update_sql = "UPDATE note 
                      SET content = ? 
                      WHERE id = ?"

    let params = [$content $scratchpad_id]
    let update_result = execute-sql $db_path $update_sql $params

    if not $update_result.success {
      return {
        success: false
        error: $"Failed to update scratchpad: ($update_result.error)"
      }
    }

    {
      success: true
      scratchpad_id: $scratchpad_id
    }
  }
}

# Get current scratchpad note
export def get-scratchpad [] {
  let db_path = get-db-path

  let sql = "SELECT id, title, content, tags, note_type, created_at, updated_at
             FROM note 
             WHERE note_type = 'scratchpad'
             LIMIT 1;"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get scratchpad: ($result.error)"
    }
  }

  if ($result.data | is-empty) {
    return {
      success: true
      scratchpad: null
    }
  }

  let scratchpad = $result.data | first | upsert tags (parse-tags ($result.data | first | get tags))

  {
    success: true
    scratchpad: $scratchpad
  }
}

# Get active lists with item counts by status for scratchpad auto-generation
export def get-active-lists-with-counts [] {
  let db_path = get-db-path

  let sql = "SELECT 
               tl.id,
               tl.name,
               tl.description,
               tl.tags,
               COUNT(CASE WHEN ti.status = 'backlog' THEN 1 END) as backlog_count,
               COUNT(CASE WHEN ti.status = 'todo' THEN 1 END) as todo_count,
               COUNT(CASE WHEN ti.status = 'in_progress' THEN 1 END) as in_progress_count,
               COUNT(CASE WHEN ti.status = 'review' THEN 1 END) as review_count,
               COUNT(CASE WHEN ti.status = 'done' THEN 1 END) as done_count,
               COUNT(CASE WHEN ti.status = 'cancelled' THEN 1 END) as cancelled_count,
               COUNT(ti.id) as total_count
             FROM todo_list tl
             LEFT JOIN todo_item ti ON tl.id = ti.list_id
             WHERE tl.status = 'active'
             GROUP BY tl.id
             ORDER BY tl.created_at DESC;"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get active lists with counts: ($result.error)"
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

# Get all in-progress items across all lists for scratchpad auto-generation
export def get-all-in-progress-items [] {
  let db_path = get-db-path

  let sql = "SELECT 
               ti.id,
               ti.list_id,
               ti.content,
               ti.priority,
               ti.started_at,
               tl.name as list_name
             FROM todo_item ti
             JOIN todo_list tl ON ti.list_id = tl.id
             WHERE ti.status = 'in_progress'
             AND tl.status = 'active'
             ORDER BY ti.priority DESC NULLS LAST, ti.started_at ASC;"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get in-progress items: ($result.error)"
    }
  }

  {
    success: true
    items: $result.data
    count: ($result.data | length)
  }
}

# Get recently completed items for scratchpad auto-generation
export def get-recently-completed-items [] {
  let db_path = get-db-path

  let sql = "SELECT 
               ti.id,
               ti.list_id,
               ti.content,
               ti.status,
               ti.priority,
               ti.completed_at,
               tl.name as list_name
             FROM todo_item ti
             JOIN todo_list tl ON ti.list_id = tl.id
             WHERE ti.status IN ('done', 'cancelled')
             AND tl.status = 'active'
             AND ti.completed_at IS NOT NULL
             ORDER BY ti.completed_at DESC
             LIMIT 20;"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get recently completed items: ($result.error)"
    }
  }

  {
    success: true
    items: $result.data
    count: ($result.data | length)
  }
}

# Get high-priority pending items for scratchpad auto-generation
export def get-high-priority-next-steps [] {
  let db_path = get-db-path

  let sql = "SELECT 
               ti.id,
               ti.list_id,
               ti.content,
               ti.status,
               ti.priority,
               tl.name as list_name
             FROM todo_item ti
             JOIN todo_list tl ON ti.list_id = tl.id
             WHERE ti.status IN ('backlog', 'todo')
             AND tl.status = 'active'
             AND ti.priority >= 4
             ORDER BY ti.priority DESC, ti.created_at ASC
             LIMIT 10;"

  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get high-priority items: ($result.error)"
    }
  }

  {
    success: true
    items: $result.data
    count: ($result.data | length)
  }
}
