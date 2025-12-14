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
