# Tests for c5t schema v2 with TEXT PRIMARY KEYs
# These tests verify the new short SHA ID schema

use std/assert
use ../storage.nu *
use ./test_helpers.nu *

# ============================================================================
# SCHEMA STRUCTURE TESTS
# ============================================================================

# Test that repo table uses TEXT primary key
export def "test repo table has TEXT primary key" [] {
  with-test-db {
    let db_path = init-database

    # Query table info
    let table_info = open $db_path | query db "PRAGMA table_info(repo)"

    # id column should be first and TEXT type
    let id_col = $table_info | where name == "id" | first
    assert ($id_col.type == "TEXT") "repo.id should be TEXT type"
    assert ($id_col.pk == 1) "repo.id should be primary key"
  }
}

# Test that task_list table uses TEXT primary key
export def "test task_list table has TEXT primary key" [] {
  with-test-db {
    let db_path = init-database

    let table_info = open $db_path | query db "PRAGMA table_info(task_list)"
    let id_col = $table_info | where name == "id" | first

    assert ($id_col.type == "TEXT") "task_list.id should be TEXT type"
    assert ($id_col.pk == 1) "task_list.id should be primary key"
  }
}

# Test that task table uses TEXT primary key
export def "test task table has TEXT primary key" [] {
  with-test-db {
    let db_path = init-database

    let table_info = open $db_path | query db "PRAGMA table_info(task)"
    let id_col = $table_info | where name == "id" | first

    assert ($id_col.type == "TEXT") "task.id should be TEXT type"
    assert ($id_col.pk == 1) "task.id should be primary key"
  }
}

# Test that note table uses TEXT primary key
export def "test note table has TEXT primary key" [] {
  with-test-db {
    let db_path = init-database

    let table_info = open $db_path | query db "PRAGMA table_info(note)"
    let id_col = $table_info | where name == "id" | first

    assert ($id_col.type == "TEXT") "note.id should be TEXT type"
    assert ($id_col.pk == 1) "note.id should be primary key"
  }
}

# ============================================================================
# ID CONSTRAINT TESTS
# ============================================================================

# Test that repo rejects invalid ID length
export def "test repo rejects invalid ID length" [] {
  with-test-db {
    let db_path = init-database

    # Try to insert with wrong length ID - CHECK constraint should prevent it
    # Note: Nushell's query db doesn't throw on CHECK constraint violations,
    # so we verify the row wasn't inserted instead of catching an error
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('abc', 'github:test/repo')"

    # Verify the row was NOT inserted (CHECK constraint worked)
    let count = open $db_path | query db "SELECT COUNT(*) as cnt FROM repo" | get cnt.0
    assert ($count == 0) "Should reject ID with wrong length - row count should be 0"
  }
}

# Test that repo accepts valid 8-char ID
export def "test repo accepts valid 8-char ID" [] {
  with-test-db {
    let db_path = init-database

    # Insert with valid 8-char ID
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"

    let repos = open $db_path | query db "SELECT id FROM repo"
    assert (($repos | length) == 1) "Should have inserted repo"
    assert ($repos.0.id == "a1b2c3d4") "ID should match"
  }
}

# ============================================================================
# FTS5 TESTS
# ============================================================================

# Test that FTS5 search still works with TEXT PKs
export def "test FTS5 search works with TEXT primary keys" [] {
  with-test-db {
    let db_path = init-database

    # Create a repo first
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"

    # Insert a note with TEXT ID
    open $db_path | query db "INSERT INTO note (id, repo_id, title, content, note_type) VALUES ('b2c3d4e5', 'a1b2c3d4', 'Test Note', 'This is searchable content', 'manual')"

    # Search using FTS
    let results = open $db_path | query db "SELECT * FROM note_fts WHERE note_fts MATCH 'searchable'"

    assert (($results | length) == 1) "FTS should find the note"
    assert ($results.0.title == "Test Note") "Should find correct note"
  }
}

# Test that FTS5 updates when note is updated
export def "test FTS5 updates on note change" [] {
  with-test-db {
    let db_path = init-database

    # Create repo and note
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"
    open $db_path | query db "INSERT INTO note (id, repo_id, title, content, note_type) VALUES ('b2c3d4e5', 'a1b2c3d4', 'Original Title', 'original content', 'manual')"

    # Update the note
    open $db_path | query db "UPDATE note SET title = 'Updated Title', content = 'updated searchable content' WHERE id = 'b2c3d4e5'"

    # Search for old content (should not find)
    let old_results = open $db_path | query db "SELECT * FROM note_fts WHERE note_fts MATCH 'original'"
    assert (($old_results | length) == 0) "Should not find old content"

    # Search for new content (should find)
    let new_results = open $db_path | query db "SELECT * FROM note_fts WHERE note_fts MATCH 'updated'"
    assert (($new_results | length) == 1) "Should find updated content"
  }
}

# Test that FTS5 deletes when note is deleted
export def "test FTS5 deletes on note removal" [] {
  with-test-db {
    let db_path = init-database

    # Create repo and note
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"
    open $db_path | query db "INSERT INTO note (id, repo_id, title, content, note_type) VALUES ('b2c3d4e5', 'a1b2c3d4', 'Test Note', 'deletable content', 'manual')"

    # Delete the note
    open $db_path | query db "DELETE FROM note WHERE id = 'b2c3d4e5'"

    # Search should not find deleted content
    let results = open $db_path | query db "SELECT * FROM note_fts WHERE note_fts MATCH 'deletable'"
    assert (($results | length) == 0) "Should not find deleted note"
  }
}

# ============================================================================
# FOREIGN KEY TESTS
# ============================================================================

# Test that task_list references repo with TEXT FK
export def "test task_list foreign key to repo works" [] {
  with-test-db {
    let db_path = init-database

    # Enable foreign keys
    open $db_path | query db "PRAGMA foreign_keys = ON"

    # Create repo
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"

    # Create task_list with valid repo_id
    open $db_path | query db "INSERT INTO task_list (id, repo_id, name) VALUES ('c3d4e5f6', 'a1b2c3d4', 'Test List')"

    let lists = open $db_path | query db "SELECT * FROM task_list"
    assert (($lists | length) == 1) "Should have created task_list"
  }
}

# Test that task references task_list with TEXT FK
export def "test task foreign key to task_list works" [] {
  with-test-db {
    let db_path = init-database

    # Create chain: repo -> task_list -> task
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"
    open $db_path | query db "INSERT INTO task_list (id, repo_id, name) VALUES ('c3d4e5f6', 'a1b2c3d4', 'Test List')"
    open $db_path | query db "INSERT INTO task (id, list_id, content) VALUES ('d4e5f6a7', 'c3d4e5f6', 'Test Task')"

    let tasks = open $db_path | query db "SELECT * FROM task"
    assert (($tasks | length) == 1) "Should have created task"
  }
}

# Test subtask with TEXT parent_id
export def "test subtask foreign key to parent task works" [] {
  with-test-db {
    let db_path = init-database

    # Create chain: repo -> task_list -> parent task -> subtask
    open $db_path | query db "INSERT INTO repo (id, remote) VALUES ('a1b2c3d4', 'github:test/repo')"
    open $db_path | query db "INSERT INTO task_list (id, repo_id, name) VALUES ('c3d4e5f6', 'a1b2c3d4', 'Test List')"
    open $db_path | query db "INSERT INTO task (id, list_id, content) VALUES ('d4e5f6a7', 'c3d4e5f6', 'Parent Task')"
    open $db_path | query db "INSERT INTO task (id, list_id, parent_id, content) VALUES ('e5f6a7b8', 'c3d4e5f6', 'd4e5f6a7', 'Subtask')"

    let subtasks = open $db_path | query db "SELECT * FROM task WHERE parent_id IS NOT NULL"
    assert (($subtasks | length) == 1) "Should have created subtask"
    assert ($subtasks.0.parent_id == "d4e5f6a7") "Parent ID should be TEXT"
  }
}

# ============================================================================
# SCHEMA CLEANUP TESTS
# ============================================================================

# Test that repo table does NOT have last_accessed_at column
export def "test repo table has no last_accessed_at" [] {
  with-test-db {
    let db_path = init-database

    let table_info = open $db_path | query db "PRAGMA table_info(repo)"
    let col_names = $table_info | get name

    assert ("last_accessed_at" not-in $col_names) "repo table should not have last_accessed_at column"
  }
}
