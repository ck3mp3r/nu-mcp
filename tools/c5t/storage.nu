# SQLite database operations for c5t tool

# Wrapper for query db - can be mocked in tests
# Exported so tests can override it
export def run-query-db [db_path: string sql: string params: list = []] {
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
export def get-note [
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

# Upsert a note - create if no note_id, update if note_id provided
export def upsert-note [
  note_id?: int
  title?: string
  content?: string
  tags?: list
] {
  let db_path = get-db-path

  # If note_id provided, update existing
  if $note_id != null {
    # Check if note exists
    let existing = get-note $note_id
    if not $existing.success {
      return $existing
    }

    # Need at least one field to update
    if $title == null and $content == null and $tags == null {
      return {
        success: false
        error: "At least one of 'title', 'content', or 'tags' must be provided for update"
      }
    }

    # Build SET clauses for fields that are provided
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

    # Always update updated_at
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

    # Return updated note
    let updated = get-note $note_id
    {
      success: true
      created: false
      note: $updated.note
    }
  } else {
    # Create new note - require title and content
    if $title == null or $content == null {
      return {
        success: false
        error: "Both 'title' and 'content' are required when creating a new note"
      }
    }

    # Use existing create-note function
    let result = create-note $title $content $tags

    if not $result.success {
      return $result
    }

    {
      success: true
      created: true
      id: $result.id
      note_id: $result.id
      title: $title
      tags: $tags
      note: {
        id: $result.id
        title: $title
      }
    }
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

# Get active lists with item counts by status for summary
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

# Get all in-progress items across all lists for summary
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

# Get recently completed items for summary
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

# Get high-priority pending items for summary
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

# Get comprehensive summary/overview for quick status at-a-glance
export def get-summary [] {
  let db_path = get-db-path

  # Get overall stats across all active lists
  let stats_sql = "SELECT 
                     COUNT(DISTINCT tl.id) as active_lists,
                     COUNT(CASE WHEN ti.status = 'backlog' THEN 1 END) as backlog_total,
                     COUNT(CASE WHEN ti.status = 'todo' THEN 1 END) as todo_total,
                     COUNT(CASE WHEN ti.status = 'in_progress' THEN 1 END) as in_progress_total,
                     COUNT(CASE WHEN ti.status = 'review' THEN 1 END) as review_total,
                     COUNT(CASE WHEN ti.status = 'done' THEN 1 END) as done_total,
                     COUNT(CASE WHEN ti.status = 'cancelled' THEN 1 END) as cancelled_total,
                     COUNT(ti.id) as total_items
                   FROM todo_list tl
                   LEFT JOIN todo_item ti ON tl.id = ti.list_id
                   WHERE tl.status = 'active';"

  let stats_result = query-sql $db_path $stats_sql

  if not $stats_result.success {
    return {
      success: false
      error: $"Failed to get summary stats: ($stats_result.error)"
    }
  }

  # Handle empty database - return zeros
  let stats = if ($stats_result.data | is-empty) {
    {
      active_lists: 0
      backlog_total: 0
      todo_total: 0
      in_progress_total: 0
      review_total: 0
      done_total: 0
      cancelled_total: 0
      total_items: 0
    }
  } else {
    $stats_result.data | first
  }

  # Get active lists with counts
  let lists_result = get-active-lists-with-counts

  if not $lists_result.success {
    return {
      success: false
      error: $"Failed to get active lists: ($lists_result.error)"
    }
  }

  # Get in-progress items
  let in_progress_result = get-all-in-progress-items

  if not $in_progress_result.success {
    return {
      success: false
      error: $"Failed to get in-progress items: ($in_progress_result.error)"
    }
  }

  # Get high-priority next steps
  let priority_result = get-high-priority-next-steps

  if not $priority_result.success {
    return {
      success: false
      error: $"Failed to get high-priority items: ($priority_result.error)"
    }
  }

  # Get recently completed items
  let completed_result = get-recently-completed-items

  if not $completed_result.success {
    return {
      success: false
      error: $"Failed to get completed items: ($completed_result.error)"
    }
  }

  {
    success: true
    summary: {
      stats: $stats
      active_lists: $lists_result.lists
      in_progress: $in_progress_result.items
      high_priority: $priority_result.items
      recently_completed: $completed_result.items
    }
  }
}

# Delete a todo item from a list
export def delete-item [
  list_id: int
  item_id: int
] {
  let db_path = get-db-path

  # First check if item exists
  if not (item-exists $list_id $item_id) {
    return {
      success: false
      error: $"Item not found: ($item_id)"
    }
  }

  let sql = "DELETE FROM todo_item WHERE id = ? AND list_id = ?"
  let params = [$item_id $list_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to delete item: ($result.error)"
    }
  }
}

# Delete a todo list (optionally with force to delete items too)
export def delete-list [
  list_id: int
  force: bool = false
] {
  let db_path = get-db-path

  # Check if list exists
  if not (list-exists $list_id) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  # If not force, check if list has items
  if not $force {
    let count_sql = "SELECT COUNT(*) as count FROM todo_item WHERE list_id = ?"
    let count_result = query-sql $db_path $count_sql [$list_id]

    if $count_result.success and ($count_result.data | is-not-empty) {
      let item_count = $count_result.data | first | get count
      if $item_count > 0 {
        return {
          success: false
          error: $"List has items \(($item_count)\). Use force=true to delete list and all items."
        }
      }
    }
  }

  # If force, delete all items first
  if $force {
    let delete_items_sql = "DELETE FROM todo_item WHERE list_id = ?"
    let items_result = execute-sql $db_path $delete_items_sql [$list_id]

    if not $items_result.success {
      return {
        success: false
        error: $"Failed to delete items: ($items_result.error)"
      }
    }
  }

  # Delete the list
  let sql = "DELETE FROM todo_list WHERE id = ?"
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

# Delete a note by ID
export def delete-note [
  note_id: int
] {
  let db_path = get-db-path

  # Check if note exists first
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

# Edit item content
# DEPRECATED: Use upsert-item instead
export def edit-item [
  list_id: int
  item_id: int
  content: string
] {
  # Validate content is not empty
  if ($content | str trim | is-empty) {
    return {
      success: false
      error: "Content cannot be empty"
    }
  }

  let db_path = get-db-path

  # Check if item exists
  if not (item-exists $list_id $item_id) {
    return {
      success: false
      error: $"Item not found: ($item_id)"
    }
  }

  let sql = "UPDATE todo_item SET content = ? WHERE id = ? AND list_id = ?"
  let params = [$content $item_id $list_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to edit item: ($result.error)"
    }
  }
}

# Upsert a todo item - create if no item_id, update if item_id provided
export def upsert-item [
  list_id: int
  item_id?: int
  content?: string
  priority?: int
  status?: string
] {
  let db_path = get-db-path

  # Check if list exists
  if not (list-exists $list_id) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  # If item_id provided, update existing
  if $item_id != null {
    # Check if item exists
    if not (item-exists $list_id $item_id) {
      return {
        success: false
        error: $"Item not found: ($item_id)"
      }
    }

    # Need at least one field to update
    if $content == null and $priority == null and $status == null {
      return {
        success: false
        error: "At least one of 'content', 'priority', or 'status' must be provided for update"
      }
    }

    # Validate content if provided
    if $content != null and ($content | str trim | is-empty) {
      return {
        success: false
        error: "Content cannot be empty"
      }
    }

    # Build SET clauses for fields that are provided
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
    let sql = $"UPDATE todo_item SET ($set_sql) WHERE id = ? AND list_id = ?"
    $params = ($params | append $item_id)
    $params = ($params | append $list_id)

    let result = execute-sql $db_path $sql $params

    if not $result.success {
      return {
        success: false
        error: $"Failed to update item: ($result.error)"
      }
    }

    # Check if all items are now completed and auto-archive if so
    if $status != null and $status in ["done" "cancelled"] {
      if (all-items-completed $list_id) {
        let archive_result = archive-todo-list $list_id
        if $archive_result.success {
          return {
            success: true
            created: false
            archived: true
            note_id: $archive_result.note_id
          }
        }
      }
    }

    # Return updated item
    let updated = get-item $list_id $item_id
    {
      success: true
      created: false
      archived: false
      item: $updated.item
    }
  } else {
    # Create new item - require content
    if $content == null {
      return {
        success: false
        error: "'content' is required when creating a new item"
      }
    }

    # Validate content is not empty
    if ($content | str trim | is-empty) {
      return {
        success: false
        error: "Content cannot be empty"
      }
    }

    # Use existing add-todo-item function
    let result = add-todo-item $list_id $content $priority $status

    if not $result.success {
      return $result
    }

    {
      success: true
      created: true
      archived: false
      id: $result.id
      item_id: $result.id
      list_id: $list_id
      content: $content
      priority: $priority
      status: ($status | default "backlog")
      item: {
        id: $result.id
        list_id: $list_id
        content: $content
        priority: $priority
        status: ($status | default "backlog")
      }
    }
  }
}

# Rename a todo list (update name and optionally description)
# DEPRECATED: Use upsert-list instead
export def rename-list [
  list_id: int
  name: string
  description?: string
] {
  # Validate name is not empty
  if ($name | str trim | is-empty) {
    return {
      success: false
      error: "Name cannot be empty"
    }
  }

  let db_path = get-db-path

  # Check if list exists
  if not (list-exists $list_id) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  # Build SQL based on whether description is provided
  let sql = if $description != null {
    "UPDATE todo_list SET name = ?, description = ? WHERE id = ?"
  } else {
    "UPDATE todo_list SET name = ? WHERE id = ?"
  }

  let params = if $description != null {
    [$name $description $list_id]
  } else {
    [$name $list_id]
  }

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to rename list: ($result.error)"
    }
  }
}

# Upsert a todo list - create if no list_id, update if list_id provided
export def upsert-list [
  list_id?: int
  name?: string
  description?: string
  tags?: list
  notes?: string
] {
  let db_path = get-db-path

  # If list_id provided, update existing
  if $list_id != null {
    # Check if list exists
    if not (list-exists $list_id) {
      return {
        success: false
        error: $"List not found: ($list_id)"
      }
    }

    # Need at least one field to update
    if $name == null and $description == null and $tags == null and $notes == null {
      return {
        success: false
        error: "At least one of 'name', 'description', 'tags', or 'notes' must be provided for update"
      }
    }

    # Validate name if provided
    if $name != null and ($name | str trim | is-empty) {
      return {
        success: false
        error: "Name cannot be empty"
      }
    }

    # Build SET clauses for fields that are provided
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

    # Always update updated_at
    $set_clauses = ($set_clauses | append "updated_at = datetime('now')")

    let set_sql = $set_clauses | str join ", "
    let sql = $"UPDATE todo_list SET ($set_sql) WHERE id = ?"
    $params = ($params | append $list_id)

    let result = execute-sql $db_path $sql $params

    if not $result.success {
      return {
        success: false
        error: $"Failed to update list: ($result.error)"
      }
    }

    # Return updated list
    let updated = get-list $list_id
    {
      success: true
      created: false
      list: $updated.list
    }
  } else {
    # Create new list - require name
    if $name == null {
      return {
        success: false
        error: "'name' is required when creating a new list"
      }
    }

    # Validate name is not empty
    if ($name | str trim | is-empty) {
      return {
        success: false
        error: "Name cannot be empty"
      }
    }

    # Use existing create-todo-list function
    let result = create-todo-list $name $description $tags

    if not $result.success {
      return $result
    }

    # If notes provided, update the newly created list with notes
    if $notes != null {
      let _ = update-todo-notes $result.id $notes
    }

    {
      success: true
      created: true
      id: $result.id
      list_id: $result.id
      name: $name
      description: $description
      tags: $tags
      notes: $notes
      list: {
        id: $result.id
        name: $name
        description: $description
        tags: $tags
        notes: $notes
      }
    }
  }
}

# Bulk add multiple items to a list
export def bulk-add-items [
  list_id: int
  items: list # List of records with content, optional priority, optional status
] {
  # Validate items list is not empty
  if ($items | is-empty) {
    return {
      success: false
      error: "Items list cannot be empty"
    }
  }

  let db_path = get-db-path

  # Check if list exists
  if not (list-exists $list_id) {
    return {
      success: false
      error: $"List not found: ($list_id)"
    }
  }

  # Add each item
  mut added_ids = []
  for item in $items {
    let content = $item.content
    let priority = if "priority" in $item { $item.priority } else { null }
    let status = if "status" in $item { $item.status } else { null }

    let result = add-todo-item $list_id $content $priority $status

    if not $result.success {
      return {
        success: false
        error: $"Failed to add item '($content)': ($result.error)"
        partial_ids: $added_ids
      }
    }

    $added_ids = ($added_ids | append $result.id)
  }

  {
    success: true
    ids: $added_ids
    count: ($added_ids | length)
  }
}

# Move an item from one list to another
export def move-item [
  source_list_id: int
  item_id: int
  target_list_id: int
] {
  let db_path = get-db-path

  # Check if item exists in source list
  if not (item-exists $source_list_id $item_id) {
    return {
      success: false
      error: $"Item not found: ($item_id) in list ($source_list_id)"
    }
  }

  # Check if target list exists
  if not (list-exists $target_list_id) {
    return {
      success: false
      error: $"Target list not found: ($target_list_id)"
    }
  }

  let sql = "UPDATE todo_item SET list_id = ? WHERE id = ? AND list_id = ?"
  let params = [$target_list_id $item_id $source_list_id]

  let result = execute-sql $db_path $sql $params

  if $result.success {
    {success: true}
  } else {
    {
      success: false
      error: $"Failed to move item: ($result.error)"
    }
  }
}

# Export all data as JSON for backup
export def export-data [] {
  let db_path = get-db-path

  # Get all lists (including archived)
  let lists_sql = "SELECT id, name, description, notes, tags, status, created_at, updated_at, archived_at 
                   FROM todo_list 
                   ORDER BY created_at"
  let lists_result = query-sql $db_path $lists_sql

  if not $lists_result.success {
    return {
      success: false
      error: $"Failed to export lists: ($lists_result.error)"
    }
  }

  # Get all items
  let items_sql = "SELECT id, list_id, content, status, priority, position, created_at, started_at, completed_at 
                   FROM todo_item 
                   ORDER BY list_id, created_at"
  let items_result = query-sql $db_path $items_sql

  if not $items_result.success {
    return {
      success: false
      error: $"Failed to export items: ($items_result.error)"
    }
  }

  # Get all notes
  let notes_sql = "SELECT id, title, content, tags, note_type, source_id, created_at, updated_at 
                   FROM note 
                   ORDER BY created_at"
  let notes_result = query-sql $db_path $notes_sql

  if not $notes_result.success {
    return {
      success: false
      error: $"Failed to export notes: ($notes_result.error)"
    }
  }

  {
    success: true
    data: {
      version: "1.0"
      exported_at: (date now | format date "%Y-%m-%dT%H:%M:%S")
      lists: $lists_result.data
      items: $items_result.data
      notes: $notes_result.data
    }
  }
}

# Bulk update status for multiple items
export def bulk-update-status [
  list_id: int
  item_ids: list<int>
  new_status: string
] {
  # Validate status
  let valid_statuses = ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
  if $new_status not-in $valid_statuses {
    return {
      success: false
      error: $"Invalid status: '($new_status)'. Must be one of: ($valid_statuses | str join ', ')"
    }
  }

  let db_path = get-db-path

  mut updated_count = 0
  mut archived = false
  mut archive_note_id = null

  for item_id in $item_ids {
    # Check if item exists
    if not (item-exists $list_id $item_id) {
      continue # Skip non-existent items
    }

    let result = update-item-status $list_id $item_id $new_status
    if $result.success {
      $updated_count = $updated_count + 1
      if $result.archived {
        $archived = true
        $archive_note_id = $result.note_id
      }
    }
  }

  {
    success: true
    count: $updated_count
    archived: $archived
    note_id: $archive_note_id
  }
}

# Get list metadata without items
export def get-list [
  list_id: int
] {
  let db_path = get-db-path

  let sql = "SELECT id, name, description, notes, tags, status, created_at, updated_at, archived_at 
             FROM todo_list 
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

# Manually archive a list (even if items aren't all complete)
export def archive-list-manual [
  list_id: int
] {
  let db_path = get-db-path

  # Check if list exists and is active
  let list_result = get-list $list_id

  if not $list_result.success {
    return $list_result
  }

  if $list_result.list.status == "archived" {
    return {
      success: false
      error: "List is already archived"
    }
  }

  # Use existing archive function
  archive-todo-list $list_id
}

# Import data from JSON backup (full restore - clears existing data)
export def import-data [
  data: record
] {
  let db_path = get-db-path

  # Validate data structure
  if "lists" not-in $data {
    return {
      success: false
      error: "Invalid data: missing 'lists' field"
    }
  }

  if "items" not-in $data {
    return {
      success: false
      error: "Invalid data: missing 'items' field"
    }
  }

  if "notes" not-in $data {
    return {
      success: false
      error: "Invalid data: missing 'notes' field"
    }
  }

  # Clear existing data (full restore)
  # Delete in order due to foreign keys
  let _ = execute-sql $db_path "DELETE FROM todo_item" []
  let _ = execute-sql $db_path "DELETE FROM todo_list" []
  let _ = execute-sql $db_path "DELETE FROM note" []

  # Track ID mappings for relational data
  mut list_id_map = {}
  mut imported_lists = 0
  mut imported_items = 0
  mut imported_notes = 0

  # Import lists
  for list in $data.lists {
    let tags_json = if $list.tags != null { $list.tags } else { null }
    let sql = "INSERT INTO todo_list (name, description, notes, tags, status, created_at, updated_at, archived_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?) 
               RETURNING id"
    let params = [
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

  # Import items
  for item in $data.items {
    let old_list_id = $item.list_id | into string
    let new_list_id = if $old_list_id in $list_id_map {
      $list_id_map | get $old_list_id
    } else {
      continue # Skip if list wasn't imported
    }

    let sql = "INSERT INTO todo_item (list_id, content, status, priority, position, created_at, started_at, completed_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    let params = [
      $new_list_id
      $item.content
      ($item.status? | default "backlog")
      ($item.priority? | default null)
      ($item.position? | default null)
      ($item.created_at? | default (date now | format date "%Y-%m-%dT%H:%M:%S"))
      ($item.started_at? | default null)
      ($item.completed_at? | default null)
    ]

    let result = execute-sql $db_path $sql $params
    if $result.success {
      $imported_items = $imported_items + 1
    }
  }

  # Import notes
  for note in $data.notes {
    let tags_json = if $note.tags != null { $note.tags } else { null }
    let source_id = if "source_id" in $note and $note.source_id != null {
      let old_id = $note.source_id | into string
      if $old_id in $list_id_map { $list_id_map | get $old_id } else { null }
    } else {
      null
    }

    let sql = "INSERT INTO note (title, content, tags, note_type, source_id, created_at, updated_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?)"
    let params = [
      $note.title
      $note.content
      $tags_json
      ($note.note_type? | default "manual")
      $source_id
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
      lists: $imported_lists
      items: $imported_items
      notes: $imported_notes
    }
  }
}
