# c5t - Context/Memory Management Tool

Context preservation across LLM sessions using SQLite and Nushell.

## Overview

c5t (Context) helps LLMs maintain state across sessions by providing:
- **Todo Lists**: Kanban-style task tracking with 6 statuses
- **Notes**: Persistent markdown documentation
- **Auto-Archive**: Completed todo lists become searchable notes
- **Full-Text Search**: FTS5 search with boolean operators
- **Session Notes**: Use tag 'session' for context that persists across conversations
- **Project Isolation**: Data is scoped per git repository (via remote URL)

## Quick Start

The tool auto-initializes on first use.

### Storage Location

- **Database**: `~/.local/share/c5t/context.db` (XDG compliant)
- **Backups**: `~/.local/share/c5t/backups/`

### Project Isolation

c5t automatically isolates data by git repository. When you run a c5t command:
1. It detects the current git remote URL (e.g., `git@github.com:org/repo.git`)
2. Normalizes it to a project identifier (e.g., `github:org/repo`)
3. All todo lists and notes are scoped to that project

This means:
- Different repositories have separate todo lists and notes
- Cloning a repo in a new location auto-links to existing data
- Use `--all-repos` flag to query across all projects

## Todo Workflow

```bash
# Create a list (upsert without list_id creates new)
c5t_upsert_list {"name": "API Feature", "tags": ["backend", "urgent"]}
# → ID: 1

# Update a list (upsert with list_id updates existing)
c5t_upsert_list {"list_id": 1, "name": "API Feature v2", "description": "Updated desc"}

# Add items (upsert without item_id creates new)
c5t_upsert_item {"list_id": 1, "content": "Research JWT", "priority": 1}
c5t_upsert_item {"list_id": 1, "content": "Implement login"}

# Update item (upsert with item_id updates existing - can change content, priority, status)
c5t_upsert_item {"list_id": 1, "item_id": 1, "content": "Research JWT libs", "status": "in_progress"}

# View list with items grouped by status
c5t_list_items {"list_id": 1}

# Update item status (backlog → todo → in_progress → review → done → cancelled)
c5t_update_item_status {"list_id": 1, "item_id": 1, "status": "done"}

# Add progress notes
c5t_update_notes {"list_id": 1, "notes": "## Progress\n\nCompleted research"}
```

**Statuses**: `backlog`, `todo`, `in_progress`, `review`, `done`, `cancelled`

**Timestamps** (auto-managed):
- `created_at`: Set when task is created
- `started_at`: Set when task moves to `in_progress` status
- `completed_at`: Set when task moves to `done` or `cancelled` status

## Subtasks

Break down complex tasks into smaller pieces:

```bash
# Create a parent task
upsert_task {"list_id": 1, "content": "Implement authentication"}
# → ID: 1

# Create subtasks with parent_id
upsert_task {"list_id": 1, "parent_id": 1, "content": "Research JWT libraries"}
upsert_task {"list_id": 1, "parent_id": 1, "content": "Implement login endpoint"}
upsert_task {"list_id": 1, "parent_id": 1, "content": "Add password hashing"}

# View all subtasks for a parent task
list_tasks {"list_id": 1, "parent_id": 1}

# List tasks shows subtask count
list_tasks {"list_id": 1}
# → Parent tasks show "(3 subtasks)" indicator
```

**Notes:**
- Subtasks inherit the same list as their parent
- Subtasks can have their own priority and status
- Parent tasks show subtask count in task lists
- Use `list_tasks` with `parent_id` to view subtasks for a specific parent

## Notes Workflow

```bash
# Create note (upsert without note_id creates new)
c5t_upsert_note {
  "title": "Architecture Decision",
  "content": "We decided to use Rust for performance",
  "tags": ["architecture", "backend"]
}

# Update note (upsert with note_id updates existing)
c5t_upsert_note {
  "note_id": 1,
  "content": "Updated: We decided to use Rust for both performance and safety"
}

# List notes
c5t_list_notes {}
c5t_list_notes {"tags": ["backend"]}
c5t_list_notes {"note_type": "manual"}  # Filter by type

# Get specific note
c5t_get_note {"note_id": 1}

# Search with FTS5
c5t_search {"query": "architecture"}
c5t_search {"query": "rust AND performance"}  # Boolean operators
c5t_search {"query": "auth*"}  # Prefix matching
c5t_search {"query": "api", "tags": ["backend"]}  # With tag filter
```

**Note Types**: `manual`

## Session Notes Pattern

Instead of a dedicated scratchpad, use regular notes with the `session` tag to maintain context across conversations:

```bash
# Create a session note to track current work
c5t_upsert_note {
  "title": "Session: Auth Feature - 2025-01-15",
  "content": "## Current Work\n\n- Working on auth feature\n- Next: rate limiting",
  "tags": ["session"]
}

# Update an existing session note (provide note_id)
c5t_upsert_note {
  "note_id": 1,
  "content": "## Current Work\n\n- Auth feature complete\n- Next: rate limiting"
}

# Find session notes when context is lost
c5t_list_notes {"tags": ["session"]}

# Or search for session context
c5t_search {"query": "current work", "tags": ["session"]}
```

### Session Note Template

```markdown
# Session: [Feature/Task Name] - [Date]

## Current Work
[What you're actively working on right now]

## Active Todo Lists
- List: [Name] (ID: X) - [X items: Y in progress, Z todo]

## Key Decisions & Learnings
- [Important decision made and reasoning]
- [Technical insight or gotcha discovered]

## Next Steps
1. [Next immediate task]
2. [Following task]

## Context
- Branch: [branch-name]
- Files modified: [key files]

---
Last updated: [timestamp]
```

**Best Practices:**
- Create session notes at major milestones
- Use the `session` tag consistently
- Include reasoning behind decisions, not just facts
- Use `c5t_list_notes {"tags": ["session"]}` at session start for context recovery

## All Available Tools

### Task Lists
- `upsert_task_list` - Create or update a list (omit list_id to create, provide to update). Supports name, description, tags, and progress notes.
- `list_task_lists` - List active lists
- `get_task_list` - Get list metadata without tasks
- `delete_task_list` - Remove a list (use force=true if has tasks)
- `upsert_task` - Create or update a task (omit task_id to create, provide to update). Can set content, priority, status, parent_id for subtasks.
- `list_tasks` - View tasks grouped by status (shows subtask count). Use `parent_id` param to list subtasks.
- `complete_task` - Mark task done (shortcut for status='done')
- `delete_task` - Remove a task
- `move_task` - Move task to another list

### Notes
- `c5t_upsert_note` - Create or update a note (omit note_id to create, provide to update)
- `c5t_list_notes` - List notes, filter by tags or type
- `c5t_get_note` - Get specific note by ID
- `c5t_delete_note` - Remove a note
- `c5t_search` - Full-text search with FTS5

### Summary
- `c5t_get_summary` - Quick status overview of active work

### Data Management
- `c5t_export_data` - Export all data to `~/.local/share/c5t/backups/backup-{timestamp}.json`
- `c5t_list_backups` - List available backup files
- `c5t_import_data` - Import data from backup file (merge or replace)
- `c5t_list_repos` - List all known repositories

## Database

- **Location**: `~/.local/share/c5t/context.db` (respects `XDG_DATA_HOME`)
- **Backups**: `~/.local/share/c5t/backups/`
- **Schema**: SQLite with INTEGER PRIMARY KEYs
- **Tables**: `repo`, `todo_list`, `todo_item`, `note`, `note_fts` (FTS5)
- **Migration**: Auto-applies on initialization

## Project Isolation

### How It Works

c5t uses git remote URLs to identify projects:

| Git Remote | Project ID |
|------------|------------|
| `git@github.com:org/repo.git` | `github:org/repo` |
| `https://github.com/org/repo.git` | `github:org/repo` |
| `git@gitlab.com:team/project.git` | `gitlab:team/project` |

### Querying Across Projects

Most read operations support an `allRepos` flag to query across all projects:

```bash
# View todos from current repo only (default)
c5t_list_active {}

# View todos from ALL repositories
c5t_list_active {"allRepos": true}

# Search notes across all projects
c5t_search {"query": "auth", "allRepos": true}

# Get summary across all projects
c5t_get_summary {"allRepos": true}
```

### Managing Repositories

```bash
# List all known repositories
c5t_list_repos {}
# Shows: ID, remote identifier, local path, last accessed
```

## FTS5 Search Syntax

- Simple: `"database"`
- Boolean: `"api AND database"`, `"auth OR user"`
- Phrase: `"error handling"`
- Prefix: `"auth*"` (matches authentication, authorize, etc.)
- NOT: `"api NOT deprecated"`

## Examples

**End-to-end workflow:**

```bash
# 1. Create list for feature work
upsert_task_list {"name": "Auth Feature", "tags": ["backend"]}
# → ID: 1

# 2. Add tasks one at a time as you discover them
upsert_task {"list_id": 1, "content": "Research JWT", "priority": 1}
# → ID: 1
upsert_task {"list_id": 1, "content": "Implement login", "priority": 1}
# → ID: 2
upsert_task {"list_id": 1, "content": "Write tests", "priority": 2}
# → ID: 3

# 3. Break down complex tasks with subtasks
upsert_task {"list_id": 1, "parent_id": 2, "content": "Add /login endpoint"}
upsert_task {"list_id": 1, "parent_id": 2, "content": "Add password validation"}

# 4. Track progress - update status via upsert_task
upsert_task {"list_id": 1, "task_id": 1, "status": "done"}

# Add progress notes to the list
upsert_task_list {"list_id": 1, "notes": "Decided on jsonwebtoken crate"}

# 5. Complete remaining tasks
complete_task {"list_id": 1, "task_id": 2}
complete_task {"list_id": 1, "task_id": 3}

# 6. Create reference notes
upsert_note {"title": "JWT Best Practices", "content": "...", "tags": ["security"]}

# 7. Search later
search {"query": "jwt AND security"}
```

## Notes

- Database auto-initializes on first tool call
- IDs are auto-generated integers (SQLite rowid)
- Tags stored as JSON arrays
- Timestamps in ISO format
- All markdown content preserved as-is
- SQL injection protected (single quote escaping)
