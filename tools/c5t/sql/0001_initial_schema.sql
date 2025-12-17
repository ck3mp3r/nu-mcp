-- c5t Database Schema
-- SQLite database for context/memory management across LLM sessions
-- Single database with repository isolation

-- Repository table - isolates data by git repository
CREATE TABLE IF NOT EXISTS repo (
    id INTEGER PRIMARY KEY,
    remote TEXT UNIQUE NOT NULL,        -- e.g. "github:ck3mp3r/nu-mcp"
    path TEXT,                          -- local absolute path (last known)
    created_at TEXT DEFAULT (datetime('now')),
    last_accessed_at TEXT DEFAULT (datetime('now'))
);

-- Task List table - tracks collections of work items
CREATE TABLE IF NOT EXISTS task_list (
    id INTEGER PRIMARY KEY,
    repo_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    notes TEXT,
    tags TEXT,  -- JSON array
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    archived_at TEXT,
    FOREIGN KEY (repo_id) REFERENCES repo(id)
);

-- Task table - individual work items within lists (supports subtasks via parent_id)
CREATE TABLE IF NOT EXISTS task (
    id INTEGER PRIMARY KEY,
    list_id INTEGER NOT NULL,
    parent_id INTEGER,  -- NULL = root task, otherwise FK to task.id for subtasks
    content TEXT NOT NULL,
    status TEXT DEFAULT 'backlog' CHECK(status IN ('backlog', 'todo', 'in_progress', 'review', 'done', 'cancelled')),
    priority INTEGER CHECK(priority BETWEEN 1 AND 5 OR priority IS NULL),
    created_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    FOREIGN KEY (list_id) REFERENCES task_list(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES task(id) ON DELETE CASCADE
);

-- Note table - persistent markdown notes
CREATE TABLE IF NOT EXISTS note (
    id INTEGER PRIMARY KEY,
    repo_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,  -- JSON array
    note_type TEXT DEFAULT 'manual' CHECK(note_type IN ('manual', 'archived_todo', 'scratchpad')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (repo_id) REFERENCES repo(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_repo_remote ON repo(remote);
CREATE INDEX IF NOT EXISTS idx_task_list_repo ON task_list(repo_id);
CREATE INDEX IF NOT EXISTS idx_task_list_status ON task_list(status);
CREATE INDEX IF NOT EXISTS idx_task_list_repo_status ON task_list(repo_id, status);
CREATE INDEX IF NOT EXISTS idx_task_list ON task(list_id);
CREATE INDEX IF NOT EXISTS idx_task_status ON task(status);
CREATE INDEX IF NOT EXISTS idx_task_list_status ON task(list_id, status);
CREATE INDEX IF NOT EXISTS idx_task_priority ON task(priority);
CREATE INDEX IF NOT EXISTS idx_task_list_priority ON task(list_id, priority);
CREATE INDEX IF NOT EXISTS idx_task_parent ON task(parent_id);
CREATE INDEX IF NOT EXISTS idx_note_repo ON note(repo_id);
CREATE INDEX IF NOT EXISTS idx_note_type ON note(note_type);
CREATE INDEX IF NOT EXISTS idx_note_repo_type ON note(repo_id, note_type);

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
CREATE TRIGGER IF NOT EXISTS task_list_update AFTER UPDATE ON task_list BEGIN
    UPDATE task_list SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS note_update AFTER UPDATE ON note BEGIN
    UPDATE note SET updated_at = datetime('now') WHERE id = NEW.id;
END;
