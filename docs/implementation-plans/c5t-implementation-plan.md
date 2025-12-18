# c5t (Context) Tool Implementation Plan

## Overview

- **Purpose**: Context/memory management tool to preserve context across sessions, track work via task lists, and store knowledge in notes. Addresses context loss in LLM continuation summaries.
- **Target Users**: Developers working on projects with nu-mcp, especially across multiple sessions
- **External Dependencies**: SQLite (via Nushell's built-in `query db` command)
- **Status**: **COMPLETE** - All milestones implemented and tested

## Problem Statement

OpenCode's context continuation summaries can lose critical details:
- File/directory locations where work is happening
- Architectural decisions and their reasoning
- Work progress and what's pending
- Project-specific patterns and gotchas

This causes developers to re-search for files, re-explain context, and lose momentum when resuming work.

## Goals

1. **Task List Management**: Track work items and progress with Kanban-style statuses
2. **Subtasks**: Break down complex tasks into smaller pieces
3. **Markdown Notes**: Store knowledge with rich formatting
4. **Search**: Find past decisions and knowledge via FTS5
5. **Per-Project Storage**: Each repository has isolated data via git remote URL
6. **Export/Import**: Backup and restore all data

## Capabilities (All Implemented)

- [x] Create task lists with tasks
- [x] Subtasks with parent_id reference
- [x] Update progress notes on task lists (markdown)
- [x] Create standalone notes (markdown)
- [x] Search notes by tags and full-text (FTS5)
- [x] List active task lists and notes
- [x] Export/import data for backup/restore
- [x] Project isolation via git remote URL

## Module Structure

- `mod.nu`: MCP interface and tool routing (20 tools)
- `storage.nu`: SQLite database operations (CRUD)
- `formatters.nu`: Output formatting using Nushell tables
- `utils.nu`: Validation and helper functions
- `sql/0001_initial_schema.sql`: Database schema
- `README.md`: User documentation

## Database Schema

### Current Schema (v1)

```sql
-- Repository tracking for project isolation
CREATE TABLE IF NOT EXISTS repo (
    id INTEGER PRIMARY KEY,
    remote TEXT NOT NULL UNIQUE,
    path TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    last_accessed TEXT DEFAULT (datetime('now'))
);

-- Task List
CREATE TABLE IF NOT EXISTS task_list (
    id INTEGER PRIMARY KEY,
    repo_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    notes TEXT,
    tags TEXT,  -- JSON array
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (repo_id) REFERENCES repo(id) ON DELETE CASCADE
);

-- Task (supports subtasks via parent_id)
CREATE TABLE IF NOT EXISTS task (
    id INTEGER PRIMARY KEY,
    list_id INTEGER NOT NULL,
    parent_id INTEGER,  -- Self-referential FK for subtasks
    content TEXT NOT NULL,
    status TEXT DEFAULT 'backlog' CHECK(status IN ('backlog', 'todo', 'in_progress', 'review', 'done', 'cancelled')),
    priority INTEGER CHECK(priority IS NULL OR (priority >= 1 AND priority <= 5)),
    created_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    FOREIGN KEY (list_id) REFERENCES task_list(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES task(id) ON DELETE CASCADE
);

-- Note
CREATE TABLE IF NOT EXISTS note (
    id INTEGER PRIMARY KEY,
    repo_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,  -- JSON array
    note_type TEXT DEFAULT 'manual' CHECK(note_type IN ('manual', 'archived_todo')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (repo_id) REFERENCES repo(id) ON DELETE CASCADE
);

-- Full-text search
CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
    title, content, content=note, content_rowid=id
);
```

### Key Design Decisions

- **INTEGER PRIMARY KEYs**: Auto-incrementing IDs for simplicity
- **repo_id foreign key**: All task_lists and notes belong to a repository
- **parent_id for subtasks**: Self-referential FK with CASCADE delete
- **No position column**: Removed as unnecessary complexity
- **No scratchpad**: Session notes pattern with tags replaces dedicated scratchpad
- **No auto-archive**: Removed as it added complexity without clear benefit

## Available Tools (20 Total)

### Repository Management
| Tool | Description |
|------|-------------|
| `upsert_repo` | Register or update a git repository |
| `list_repos` | List all known repositories |

### Task Lists
| Tool | Description |
|------|-------------|
| `upsert_task_list` | Create or update a task list |
| `list_task_lists` | List task lists with status counts |
| `get_task_list` | Get list metadata |
| `delete_task_list` | Remove a list (force=true if has tasks) |

### Tasks
| Tool | Description |
|------|-------------|
| `upsert_task` | Create or update a task (supports parent_id for subtasks) |
| `list_tasks` | View tasks, filter by status array or parent_id |
| `complete_task` | Mark task as done |
| `delete_task` | Remove a task |
| `move_task` | Move task to another list |

### Notes
| Tool | Description |
|------|-------------|
| `upsert_note` | Create or update a note |
| `list_notes` | List notes with optional filters |
| `get_note` | Get specific note by ID |
| `delete_note` | Remove a note |
| `search` | FTS5 full-text search |

### Summary & Data
| Tool | Description |
|------|-------------|
| `get_summary` | Quick status overview with recent completions |
| `export_data` | Export all data to JSON backup |
| `import_data` | Import data from backup (replaces existing) |
| `list_backups` | List available backup files |

## Output Formatting

All table outputs use Nushell's native table rendering:
- Box-drawing characters for borders
- Word wrapping after 10 words for long content
- Status emojis: `backlog`, `todo`, `in_progress`, `review`, `done`, `cancelled`
- Compact task table columns: ID, P (priority), Content, S (status emoji)
- Tool descriptions instruct LLM to display output directly

## Implementation Status

All milestones complete:

| Milestone | Description | Status |
|-----------|-------------|--------|
| 1 | Basic Structure & Database | COMPLETE |
| 2 | Task List Creation | COMPLETE |
| 3 | Tasks Management | COMPLETE |
| 4 | Progress Notes | COMPLETE |
| 5 | Subtasks | COMPLETE |
| 6 | Standalone Notes | COMPLETE |
| 7 | Full-Text Search | COMPLETE |
| 8 | Export/Import | COMPLETE |
| 9 | Formatters & Output | COMPLETE |
| 10 | Error Handling | COMPLETE |
| 11 | Documentation | COMPLETE |
| 12 | Testing | COMPLETE (52 tests) |

## Testing

- **52 unit/integration tests** in `tests/` directory
- Test files:
  - `test_mod.nu` - Tool schema and routing tests
  - `test_formatters.nu` - Output formatting tests
  - `test_utils.nu` - Validation function tests
  - `test_subtasks.nu` - Subtask functionality tests
  - `test_task_schema.nu` - Database schema tests
  - `test_helpers.nu` - Test utilities

Run tests:
```bash
nu tools/c5t/tests/run_tests.nu
```

## Key Changes from Original Plan

1. **Removed auto-archive**: Too complex, manual workflow preferred
2. **Removed scratchpad**: Session notes pattern with tags is more flexible
3. **Renamed todo_list/todo_item to task_list/task**: Clearer terminology
4. **Added subtasks**: Via parent_id self-referential FK
5. **Added project isolation**: Via repo table and git remote detection
6. **Added export/import**: JSON backup with v2.0 format
7. **Changed IDs**: From TEXT UUIDs to INTEGER auto-increment
8. **Status filter**: Changed from single enum to array of statuses
9. **Removed position column**: Unnecessary complexity
10. **Native table output**: Switched from markdown to Nushell tables

## Future Enhancements

### Potential Additions
- Kanban board visualization (`get_board` tool)
- Task templates
- Due dates and reminders
- Links between notes (Obsidian-style)
- Statistics and velocity tracking
- Recurring tasks

### Not Planned
- Auto-archive (removed as too complex)
- Dedicated scratchpad (session notes pattern preferred)
- Position/ordering within lists (removed)

## References

- [Tool README](../../tools/c5t/README.md)
- [Tool Development Guide](../tool-development.md)
- [Nushell SQLite Documentation](https://www.nushell.sh/book/loading_data.html)
- [SQLite FTS5](https://www.sqlite.org/fts5.html)
