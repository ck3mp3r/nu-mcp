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

# Get list of migration files in order
def get-migration-files [] {
  let sql_dir = "tools/c5t/sql"

  # List all .sql files in the sql directory and sort them
  glob $"($sql_dir)/*.sql" | sort
}

# Extract version from migration filename (e.g., "0001" from "0001_initial_schema.sql")
def get-migration-version [filepath: string] {
  $filepath | path basename | split row "_" | first
}

# Check if migration has been applied
def migration-applied [db_path: string version: string] {
  try {
    # Query schema_migrations table
    let result = sqlite3 -json $db_path $"SELECT version FROM schema_migrations WHERE version = '($version)';"

    # Parse JSON if not empty
    if ($result | str trim | is-empty) {
      false
    } else {
      let parsed = $result | from json
      ($parsed | length) > 0
    }
  } catch {
    # If table doesn't exist yet, no migrations have been applied
    false
  }
}

# Record that a migration has been applied
def record-migration [db_path: string version: string] {
  sqlite3 $db_path $"INSERT OR IGNORE INTO schema_migrations \(version\) VALUES \('($version)'\);"
}

# Create database schema (tables, indexes, triggers)
# Runs all migration files in order, tracking which have been applied
def create-schema [db_path: string] {
  # Always ensure migrations table exists first
  let migrations_table_sql = "CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
  );"
  sqlite3 $db_path $migrations_table_sql

  # Get all migration files
  let migrations = get-migration-files

  # Execute each migration in order
  # Use 'sqlite3' not '^sqlite3' so mocks can intercept
  for migration in $migrations {
    let version = get-migration-version $migration

    # Check if this migration has already been applied
    if not (migration-applied $db_path $version) {
      # Apply the migration
      sqlite3 $db_path $".read ($migration)"

      # Record that we applied it
      record-migration $db_path $version
    }
  }
}

# Execute SQL query and return result (abstraction over sqlite3)
def execute-sql [db_path: string sql: string] {
  try {
    # Use 'sqlite3' not '^sqlite3' so mocks can intercept
    sqlite3 $db_path $sql
    {success: true output: ""}
  } catch {|err|
    {success: false error: $err.msg}
  }
}

# Execute SQL query and return JSON result
def query-sql [db_path: string sql: string] {
  try {
    # Use 'sqlite3' not '^sqlite3' so mocks can intercept
    let result = sqlite3 -json $db_path $sql | from json
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
