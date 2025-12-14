# SQLite database operations for c5t tool

# Get the database path (in .c5t directory of current project)
export def get-db-path [] {
  let db_dir = ".c5t"

  # Create .c5t directory if it doesn't exist
  if not ($db_dir | path exists) {
    mkdir $db_dir
  }

  $"($db_dir)/context.db"
}

# Initialize database and create schema if needed
export def init-database [] {
  let db_path = get-db-path

  # Create all tables and indexes
  create-schema $db_path

  $db_path
}

# Execute SQL command on database
def run-sql [db_path: string sql: string] {
  try {
    ^sqlite3 $db_path $sql
  } catch {
    # Ignore errors for IF NOT EXISTS statements
    null
  }
}

# Create database schema (tables, indexes, triggers)
def create-schema [db_path: string] {
  # Todo List table
  run-sql $db_path "CREATE TABLE IF NOT EXISTS todo_list (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        tags TEXT,
        status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        archived_at TEXT
    );"

  # Todo Item table
  run-sql $db_path "CREATE TABLE IF NOT EXISTS todo_item (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        content TEXT NOT NULL,
        status TEXT DEFAULT 'todo' CHECK(status IN ('backlog', 'todo', 'in_progress', 'review', 'done', 'cancelled')),
        position INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        started_at TEXT,
        completed_at TEXT,
        FOREIGN KEY (list_id) REFERENCES todo_list(id) ON DELETE CASCADE
    );"

  # Note table
  run-sql $db_path "CREATE TABLE IF NOT EXISTS note (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tags TEXT,
        note_type TEXT DEFAULT 'manual' CHECK(note_type IN ('manual', 'archived_todo', 'scratchpad')),
        source_id TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );"

  # Indexes
  run-sql $db_path "CREATE INDEX IF NOT EXISTS idx_todo_list_status ON todo_list(status);"
  run-sql $db_path "CREATE INDEX IF NOT EXISTS idx_todo_item_list ON todo_item(list_id);"
  run-sql $db_path "CREATE INDEX IF NOT EXISTS idx_todo_item_status ON todo_item(status);"
  run-sql $db_path "CREATE INDEX IF NOT EXISTS idx_todo_item_list_status ON todo_item(list_id, status);"
  run-sql $db_path "CREATE INDEX IF NOT EXISTS idx_note_type ON note(note_type);"

  # Full-text search virtual table
  run-sql $db_path "CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
        title,
        content,
        content=note,
        content_rowid=id
    );"

  # FTS sync triggers
  run-sql $db_path "CREATE TRIGGER IF NOT EXISTS note_ai AFTER INSERT ON note BEGIN
        INSERT INTO note_fts(rowid, title, content) 
        VALUES (new.id, new.title, new.content);
    END;"

  run-sql $db_path "CREATE TRIGGER IF NOT EXISTS note_au AFTER UPDATE ON note BEGIN
        UPDATE note_fts SET title = new.title, content = new.content 
        WHERE rowid = new.id;
    END;"

  run-sql $db_path "CREATE TRIGGER IF NOT EXISTS note_ad AFTER DELETE ON note BEGIN
        DELETE FROM note_fts WHERE rowid = old.id;
    END;"

  # Auto-update timestamp triggers
  run-sql $db_path "CREATE TRIGGER IF NOT EXISTS todo_list_update AFTER UPDATE ON todo_list BEGIN
        UPDATE todo_list SET updated_at = datetime('now') WHERE id = NEW.id;
    END;"

  run-sql $db_path "CREATE TRIGGER IF NOT EXISTS note_update AFTER UPDATE ON note BEGIN
        UPDATE note SET updated_at = datetime('now') WHERE id = NEW.id;
    END;"
}

# Execute SQL query and return result (abstraction over sqlite3)
def execute-sql [db_path: string sql: string] {
  try {
    ^sqlite3 $db_path $sql
    {success: true output: ""}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

# Execute SQL query and return JSON result
def query-sql [db_path: string sql: string] {
  try {
    let result = ^sqlite3 -json $db_path $sql | from json
    {success: true data: $result}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

# Create a new todo list
export def create-todo-list [
  name: string
  description?: string
  tags?: list
] {
  let db_path = get-db-path

  # Generate ID using abstracted function
  use utils.nu generate-id
  let id = generate-id

  # Convert tags to JSON array if provided
  let tags_json = if $tags != null and ($tags | is-not-empty) {
    $tags | to json --raw
  } else {
    "null"
  }

  # Build SQL with proper escaping
  let escaped_name = $name | str replace --all "'" "''"
  let desc_value = if $description != null {
    let escaped_desc = $description | str replace --all "'" "''"
    $"'($escaped_desc)'"
  } else {
    "null"
  }

  let sql = $"INSERT INTO todo_list \(id, name, description, tags\) 
             VALUES \('($id)', '($escaped_name)', ($desc_value), '($tags_json)'\);"

  # Use abstracted SQL execution
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

# Parse tags from JSON string (abstraction for tag handling)
def parse-tags [tags_json: any] {
  if $tags_json != null and $tags_json != "" {
    try { $tags_json | from json } catch { [] }
  } else {
    []
  }
}

# Get all active todo lists
export def get-active-lists [
  tag_filter?: list
] {
  let db_path = get-db-path

  # Base query for active lists
  let sql = "SELECT id, name, description, tags, created_at, updated_at 
             FROM todo_list 
             WHERE status = 'active' 
             ORDER BY created_at DESC;"

  # Use abstracted query execution
  let result = query-sql $db_path $sql

  if not $result.success {
    return {
      success: false
      error: $"Failed to get active lists: ($result.error)"
    }
  }

  let results = $result.data

  # Filter by tags if provided (pure function - no external dependencies)
  let filtered = if $tag_filter != null and ($tag_filter | is-not-empty) {
    $results | where {|row|
      let row_tags = parse-tags $row.tags
      # Check if any filter tag is in row tags
      ($tag_filter | any {|tag| $tag in $row_tags })
    }
  } else {
    $results
  }

  # Parse tags JSON in each result (pure data transformation)
  let parsed = $filtered | each {|row|
    $row | upsert tags (parse-tags $row.tags)
  }

  {
    success: true
    lists: $parsed
    count: ($parsed | length)
  }
}
