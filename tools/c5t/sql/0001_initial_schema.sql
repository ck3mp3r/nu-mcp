-- c5t Database Schema - Initial Migration
-- SQLite database for context/memory management across LLM sessions
-- Single database with project isolation

-- Schema migrations table - tracks which migrations have been applied
CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
);

-- Project table - isolates data by project directory
CREATE TABLE IF NOT EXISTS project (
    id INTEGER PRIMARY KEY,
    project_key TEXT UNIQUE NOT NULL,  -- e.g. "abc12345-myproject" or "__global__"
    path TEXT,                          -- absolute path, NULL for __global__
    name TEXT NOT NULL,                 -- human-readable name
    created_at TEXT DEFAULT (datetime('now')),
    last_accessed_at TEXT DEFAULT (datetime('now'))
);

-- Todo List table - tracks collections of work items
CREATE TABLE IF NOT EXISTS todo_list (
    id INTEGER PRIMARY KEY,
    project_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    notes TEXT,
    tags TEXT,  -- JSON array
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    archived_at TEXT,
    FOREIGN KEY (project_id) REFERENCES project(id)
);

-- Todo Item table - individual work items within lists
CREATE TABLE IF NOT EXISTS todo_item (
    id INTEGER PRIMARY KEY,
    list_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    status TEXT DEFAULT 'backlog' CHECK(status IN ('backlog', 'todo', 'in_progress', 'review', 'done', 'cancelled')),
    priority INTEGER CHECK(priority BETWEEN 1 AND 5 OR priority IS NULL),
    position INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    FOREIGN KEY (list_id) REFERENCES todo_list(id) ON DELETE CASCADE
);

-- Note table - persistent markdown notes
CREATE TABLE IF NOT EXISTS note (
    id INTEGER PRIMARY KEY,
    project_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,  -- JSON array
    note_type TEXT DEFAULT 'manual' CHECK(note_type IN ('manual', 'archived_todo', 'scratchpad')),
    source_id INTEGER,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (project_id) REFERENCES project(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_project_key ON project(project_key);
CREATE INDEX IF NOT EXISTS idx_todo_list_project ON todo_list(project_id);
CREATE INDEX IF NOT EXISTS idx_todo_list_status ON todo_list(status);
CREATE INDEX IF NOT EXISTS idx_todo_list_project_status ON todo_list(project_id, status);
CREATE INDEX IF NOT EXISTS idx_todo_item_list ON todo_item(list_id);
CREATE INDEX IF NOT EXISTS idx_todo_item_status ON todo_item(status);
CREATE INDEX IF NOT EXISTS idx_todo_item_list_status ON todo_item(list_id, status);
CREATE INDEX IF NOT EXISTS idx_todo_item_priority ON todo_item(priority);
CREATE INDEX IF NOT EXISTS idx_todo_item_list_priority ON todo_item(list_id, priority);
CREATE INDEX IF NOT EXISTS idx_note_project ON note(project_id);
CREATE INDEX IF NOT EXISTS idx_note_type ON note(note_type);
CREATE INDEX IF NOT EXISTS idx_note_project_type ON note(project_id, note_type);

-- Full-text search virtual table for notes
CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
    title,
    content,
    content='note',
    content_rowid='id'
);

-- FTS sync triggers - keep full-text index in sync with note table
CREATE TRIGGER IF NOT EXISTS note_ai AFTER INSERT ON note BEGIN
    INSERT INTO note_fts(rowid, title, content) 
    VALUES (new.id, new.title, new.content);
END;

CREATE TRIGGER IF NOT EXISTS note_au AFTER UPDATE ON note BEGIN
    UPDATE note_fts SET title = new.title, content = new.content 
    WHERE rowid = new.id;
END;

CREATE TRIGGER IF NOT EXISTS note_ad AFTER DELETE ON note BEGIN
    DELETE FROM note_fts WHERE rowid = old.id;
END;

-- Auto-update timestamp triggers
CREATE TRIGGER IF NOT EXISTS todo_list_update AFTER UPDATE ON todo_list BEGIN
    UPDATE todo_list SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS note_update AFTER UPDATE ON note BEGIN
    UPDATE note SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Insert global pseudo-project (always project_id = 1)
INSERT OR IGNORE INTO project (id, project_key, path, name) 
VALUES (1, '__global__', NULL, 'Global');
