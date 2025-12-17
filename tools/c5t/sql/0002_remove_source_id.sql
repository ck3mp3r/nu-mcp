-- Migration 0002: Remove source_id from note table
-- The source_id column is no longer needed since archived lists are deleted
-- after creating the archive note (list title is preserved in note title)

-- SQLite doesn't support DROP COLUMN directly, so we need to recreate the table
-- Step 1: Create new table without source_id
CREATE TABLE note_new (
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

-- Step 2: Copy data (excluding source_id)
INSERT INTO note_new (id, repo_id, title, content, tags, note_type, created_at, updated_at)
SELECT id, repo_id, title, content, tags, note_type, created_at, updated_at
FROM note;

-- Step 3: Drop old table
DROP TABLE note;

-- Step 4: Rename new table
ALTER TABLE note_new RENAME TO note;

-- Step 5: Recreate indexes
CREATE INDEX idx_note_repo ON note(repo_id);
CREATE INDEX idx_note_type ON note(note_type);
CREATE INDEX idx_note_repo_type ON note(repo_id, note_type);

-- Step 6: Recreate FTS table and triggers
DROP TRIGGER IF EXISTS note_ai;
DROP TRIGGER IF EXISTS note_au;
DROP TRIGGER IF EXISTS note_ad;
DROP TABLE IF EXISTS note_fts;

CREATE VIRTUAL TABLE note_fts USING fts5(
    title,
    content,
    content='note',
    content_rowid='id'
);

-- Rebuild FTS index from existing notes
INSERT INTO note_fts(rowid, title, content)
SELECT id, title, content FROM note;

-- Recreate FTS sync triggers
CREATE TRIGGER note_ai AFTER INSERT ON note BEGIN
    INSERT INTO note_fts(rowid, title, content) 
    VALUES (new.id, new.title, new.content);
END;

CREATE TRIGGER note_au AFTER UPDATE ON note BEGIN
    UPDATE note_fts SET title = new.title, content = new.content 
    WHERE rowid = new.id;
END;

CREATE TRIGGER note_ad AFTER DELETE ON note BEGIN
    DELETE FROM note_fts WHERE rowid = old.id;
END;

-- Recreate auto-update trigger
DROP TRIGGER IF EXISTS note_update;
CREATE TRIGGER note_update AFTER UPDATE ON note BEGIN
    UPDATE note SET updated_at = datetime('now') WHERE id = NEW.id;
END;
