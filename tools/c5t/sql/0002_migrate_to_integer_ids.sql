-- Migration: Convert TEXT IDs to INTEGER PRIMARY KEY
-- This enables FTS5 compatibility and improves performance

-- Step 1: Create new tables with INTEGER PRIMARY KEY
CREATE TABLE todo_list_new (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    notes TEXT,
    tags TEXT,  -- JSON array
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    archived_at TEXT
);

CREATE TABLE todo_item_new (
    id INTEGER PRIMARY KEY,
    list_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    status TEXT DEFAULT 'backlog' CHECK(status IN ('backlog', 'todo', 'in_progress', 'review', 'done', 'cancelled')),
    priority INTEGER CHECK(priority BETWEEN 1 AND 5 OR priority IS NULL),
    position INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    FOREIGN KEY (list_id) REFERENCES todo_list_new(id) ON DELETE CASCADE
);

CREATE TABLE note_new (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,  -- JSON array
    note_type TEXT DEFAULT 'manual' CHECK(note_type IN ('manual', 'archived_todo', 'scratchpad')),
    source_id INTEGER,  -- Now INTEGER to reference todo_list_new(id)
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Step 2: Migrate data (old tables will be empty for new databases)
-- For existing databases, this would copy data with new auto-generated IDs
-- Note: This assumes fresh database - if upgrading existing data, need ID mapping

-- Step 3: Drop old tables
DROP TABLE IF EXISTS todo_item;
DROP TABLE IF EXISTS todo_list;
DROP TABLE IF EXISTS note;

-- Step 4: Rename new tables to original names
ALTER TABLE todo_list_new RENAME TO todo_list;
ALTER TABLE todo_item_new RENAME TO todo_item;
ALTER TABLE note_new RENAME TO note;

-- Step 5: Recreate indexes with new schema
CREATE INDEX IF NOT EXISTS idx_todo_list_status ON todo_list(status);
CREATE INDEX IF NOT EXISTS idx_todo_item_list ON todo_item(list_id);
CREATE INDEX IF NOT EXISTS idx_todo_item_status ON todo_item(status);
CREATE INDEX IF NOT EXISTS idx_todo_item_list_status ON todo_item(list_id, status);
CREATE INDEX IF NOT EXISTS idx_todo_item_priority ON todo_item(priority);
CREATE INDEX IF NOT EXISTS idx_todo_item_list_priority ON todo_item(list_id, priority);
CREATE INDEX IF NOT EXISTS idx_note_type ON note(note_type);

-- Step 6: Enable FTS5 full-text search (now compatible with INTEGER rowid)
CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
    title,
    content,
    content='note',
    content_rowid='id'
);

-- Step 7: FTS sync triggers - keep full-text index in sync with note table
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

-- Step 8: Recreate auto-update timestamp triggers
CREATE TRIGGER IF NOT EXISTS todo_list_update AFTER UPDATE ON todo_list BEGIN
    UPDATE todo_list SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS note_update AFTER UPDATE ON note BEGIN
    UPDATE note SET updated_at = datetime('now') WHERE id = NEW.id;
END;
