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
      sqlite3 $db_path $".read ($migration)"
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

  let sql = "SELECT id, name, description, tags, created_at, updated_at 
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
