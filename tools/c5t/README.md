# c5t - Context/Memory Management Tool

Context preservation across LLM sessions using SQLite and Nushell.

## Overview

c5t (Context) helps LLMs maintain state across sessions by providing:
- **Task Lists**: Kanban-style task tracking with 6 statuses
- **Subtasks**: Break down complex tasks into smaller pieces
- **Notes**: Persistent markdown documentation
- **Full-Text Search**: FTS5 search with boolean operators
- **Session Notes**: Use tag 'session' for context that persists across conversations
- **Project Isolation**: Data is scoped per git repository (via remote URL)
- **Export/Import**: Backup and restore all data

## Quick Start

The tool auto-initializes on first use. Register your repository first:

```bash
# Register the current git repository
upsert_repo {}
```

### Storage Location

- **Database**: `~/.local/share/c5t/context.db` (XDG compliant)
- **Backups**: `~/.local/share/c5t/backups/`

### Project Isolation

c5t automatically isolates data by git repository. When you run a c5t command:
1. It detects the current git remote URL (e.g., `git@github.com:org/repo.git`)
2. Normalizes it to a project identifier (e.g., `github:org/repo`)
3. All task lists and notes are scoped to that project

This means:
- Different repositories have separate task lists and notes
- Cloning a repo in a new location auto-links to existing data
- Use `all_repos: true` parameter to query across all projects

## Task Workflow

```bash
# Register repo first (required before creating lists/notes)
upsert_repo {}

# Create a list (upsert without list_id creates new)
upsert_task_list {"name": "API Feature", "tags": ["backend", "urgent"]}
# -> ID: 1

# Update a list (upsert with list_id updates existing)
upsert_task_list {"list_id": 1, "name": "API Feature v2", "description": "Updated desc"}

# Add tasks (upsert without task_id creates new)
upsert_task {"list_id": 1, "content": "Research JWT", "priority": 1}
upsert_task {"list_id": 1, "content": "Implement login"}

# Update task (upsert with task_id updates existing - can change content, priority, status)
upsert_task {"list_id": 1, "task_id": 1, "content": "Research JWT libs", "status": "in_progress"}

# View list with tasks grouped by status
list_tasks {"list_id": 1}

# Filter by status (array of statuses)
list_tasks {"list_id": 1, "status": ["todo", "in_progress"]}

# Complete a task
complete_task {"list_id": 1, "task_id": 1}

# Add progress notes to the list
upsert_task_list {"list_id": 1, "notes": "## Progress\n\nCompleted research"}

# Archive a completed list (sets status='archived', records timestamp)
archive_task_list {"list_id": 1}

# View archived lists
list_task_lists {"status": "archived"}

# View all lists (active and archived)
list_task_lists {"status": "all"}
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
# -> ID: 1

# Create subtasks with parent_id
upsert_task {"list_id": 1, "parent_id": 1, "content": "Research JWT libraries"}
upsert_task {"list_id": 1, "parent_id": 1, "content": "Implement login endpoint"}
upsert_task {"list_id": 1, "parent_id": 1, "content": "Add password hashing"}

# View all subtasks for a parent task
list_tasks {"list_id": 1, "parent_id": 1}

# List tasks shows subtask count
list_tasks {"list_id": 1}
# -> Parent tasks show "(3 subtasks)" indicator
```

**Notes:**
- Subtasks inherit the same list as their parent
- Subtasks can have their own priority and status
- Parent tasks show subtask count in task lists
- Use `list_tasks` with `parent_id` to view subtasks for a specific parent
- Deleting a parent task cascades to delete all subtasks

## Archiving Task Lists

Archive completed task lists to keep your workspace clean while preserving history:

```bash
# Archive a completed list
archive_task_list {"list_id": "abc12345"}

# List only active lists (default behavior)
list_task_lists {}

# List only archived lists
list_task_lists {"status": "archived"}

# List all lists (active and archived)
list_task_lists {"status": "all"}
```

**How archiving works:**
- Sets list `status` to 'archived'
- Records `archived_at` timestamp
- Archived lists are excluded from default `list_task_lists` output
- Tasks within archived lists remain accessible
- Archiving is idempotent (can archive an already-archived list)
- Use `status` parameter to view archived lists

**Why archive instead of delete:**
- Preserves work history and completed tasks
- Keeps your active list view clean
- Can be synced across machines (unlike deleted data)
- No risk of accidental data loss

## Notes Workflow

```bash
# Create note (upsert without note_id creates new)
upsert_note {
  "title": "Architecture Decision",
  "content": "We decided to use Rust for performance",
  "tags": ["architecture", "backend"]
}

# Update note (upsert with note_id updates existing)
upsert_note {
  "note_id": 1,
  "content": "Updated: We decided to use Rust for both performance and safety"
}

# List notes
list_notes {}
list_notes {"tags": ["backend"]}
list_notes {"note_type": "manual"}  # Filter by type

# Get specific note
get_note {"note_id": 1}

# Search with FTS5
search {"query": "architecture"}
search {"query": "rust AND performance"}  # Boolean operators
search {"query": "auth*"}  # Prefix matching
search {"query": "api", "tags": ["backend"]}  # With tag filter
```

**Note Types**: `manual`, `archived_todo` (from completed task lists)

## Session Notes Pattern

Instead of a dedicated scratchpad, use regular notes with the `session` tag to maintain context across conversations:

```bash
# Create a session note to track current work
upsert_note {
  "title": "Session: Auth Feature - 2025-01-15",
  "content": "## Current Work\n\n- Working on auth feature\n- Next: rate limiting",
  "tags": ["session"]
}

# Update an existing session note (provide note_id)
upsert_note {
  "note_id": 1,
  "content": "## Current Work\n\n- Auth feature complete\n- Next: rate limiting"
}

# Find session notes when context is lost
list_notes {"tags": ["session"]}

# Or search for session context
search {"query": "current work", "tags": ["session"]}
```

### Session Note Template

```markdown
# Session: [Feature/Task Name] - [Date]

## Current Work
[What you're actively working on right now]

## Active Task Lists
- List: [Name] (ID: X) - [X tasks: Y in progress, Z todo]

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
- Use `list_notes {"tags": ["session"]}` at session start for context recovery

## All Available Tools

### Repository Management
- `upsert_repo` - Register or update a git repository (required before creating lists/notes)
- `list_repos` - List all known repositories

### Task Lists
- `upsert_task_list` - Create or update a list (omit list_id to create, provide to update). Supports name, description, tags, and progress notes.
- `list_task_lists` - List task lists with status counts
- `get_task_list` - Get list metadata without tasks
- `archive_task_list` - Archive a list (sets status='archived', excluded from default views)
- `delete_task_list` - Remove a list (use force=true if has tasks)

### Tasks
- `upsert_task` - Create or update a task (omit task_id to create, provide to update). Can set content, priority, status, parent_id for subtasks.
- `list_tasks` - View tasks grouped by status (shows subtask count). Use `parent_id` param to list subtasks. Use `status` array param to filter.
- `complete_task` - Mark task done (shortcut for status='done')
- `delete_task` - Remove a task
- `move_task` - Move task to another list

### Notes
- `upsert_note` - Create or update a note (omit note_id to create, provide to update)
- `list_notes` - List notes, filter by tags or type
- `get_note` - Get specific note by ID
- `delete_note` - Remove a note
- `search` - Full-text search with FTS5

### Summary
- `get_summary` - Quick status overview of active work, including recently completed tasks

### Sync
- `sync_init` - Initialize git repo in sync directory, optionally add remote
- `sync_status` - Show sync configuration and status
- `sync_refresh` - Pull from remote and import to database (also runs on startup)
- `sync_export` - Export to JSONL, commit, and push to remote

### Backup
- `export_data` - Export all data to `~/.local/share/c5t/backups/backup-{timestamp}.json`
- `list_backups` - List available backup files
- `import_data` - Import data from backup file (replaces all existing data)

## Database

- **Location**: `~/.local/share/c5t/context.db` (respects `XDG_DATA_HOME`)
- **Backups**: `~/.local/share/c5t/backups/`
- **Sync**: `~/.local/share/c5t/sync/` (JSONL files in git repo)
- **Schema**: SQLite with TEXT PRIMARY KEYs (8-char hex IDs)
- **Tables**: `repo`, `task_list`, `task`, `note`, `note_fts` (FTS5)
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

Most read operations support an `all_repos` flag to query across all projects:

```bash
# View task lists from current repo only (default)
list_task_lists {}

# View task lists from ALL repositories
list_task_lists {"all_repos": true}

# Search notes across all projects
search {"query": "auth", "all_repos": true}

# Get summary across all projects
get_summary {"all_repos": true}
```

### Managing Repositories

```bash
# Register current directory's git repo
upsert_repo {}

# List all known repositories
list_repos {}
# Shows: ID, remote identifier, local path, last accessed
```

## FTS5 Search Syntax

- Simple: `"database"`
- Boolean: `"api AND database"`, `"auth OR user"`
- Phrase: `"error handling"`
- Prefix: `"auth*"` (matches authentication, authorize, etc.)
- NOT: `"api NOT deprecated"`

## Sync Across Machines

c5t supports syncing your data across machines using a git repository. Your task lists, tasks, and notes are exported to JSONL files and can be pushed/pulled via git.

### Storage Location

- **Sync Directory**: `~/.local/share/c5t/sync/`
- **Sync Files**: `repos.jsonl`, `lists.jsonl`, `tasks.jsonl`, `notes.jsonl`

### Setting Up Sync

```bash
# 1. Initialize sync (creates git repo in sync directory)
sync_init {}

# 2. Add a remote for syncing across machines
sync_init {"remote_url": "git@github.com:username/c5t-sync.git"}

# 3. Check sync status
sync_status {}
```

### Syncing Data

```bash
# Pull latest changes from remote and import to database
sync_refresh {}

# Export local database and push to remote
sync_export {}
sync_export {"message": "Added new auth tasks"}
```

### How It Works

1. **sync_refresh** (also runs automatically on MCP startup):
   - Checks if sync is configured (git repo exists)
   - Pulls latest changes from remote
   - Imports JSONL files into local database
   - Uses last-write-wins conflict resolution (via `updated_at` timestamps)

2. **sync_export**:
   - Pulls latest first (to avoid conflicts)
   - Exports all data to JSONL files
   - Commits with auto-generated or custom message
   - Pushes to remote

### Conflict Resolution

c5t uses **last-write-wins** based on `updated_at` timestamps:
- When importing, if a record exists locally and in sync files, the newer one wins
- Tasks use `completed_at` for comparison
- Repos are overwritten (path is just metadata, identity is by remote)

### Sync Tools

| Tool | Description |
|------|-------------|
| `sync_init` | Initialize git repo in sync directory, optionally add remote |
| `sync_status` | Show sync configuration and status |
| `sync_refresh` | Pull from remote and import to database |
| `sync_export` | Export to JSONL, commit, and push to remote |

### Manual Git Operations

The sync directory is a standard git repo. You can use git directly:

```bash
cd ~/.local/share/c5t/sync

# Add remote manually
git remote add origin git@github.com:username/c5t-sync.git

# View history
git log --oneline

# Resolve conflicts manually if needed
git status
```

## Export/Import (Backup)

For one-time backups (not sync), use export/import:

### Backup Your Data

```bash
# Export all data to timestamped backup file
export_data {}
# -> Saves to ~/.local/share/c5t/backups/backup-YYYYMMDD-HHMMSS.json

# List available backups
list_backups {}
```

### Restore Data

```bash
# Import from a backup (replaces all existing data)
import_data {"filename": "backup-20251218-114006.json"}
```

**Note**: Import replaces all existing data. The backup format (v2.0) includes repositories, task lists, tasks, and notes with proper ID mapping.

## Examples

**End-to-end workflow:**

```bash
# 1. Register the repository
upsert_repo {}

# 2. Create list for feature work
upsert_task_list {"name": "Auth Feature", "tags": ["backend"]}
# -> ID: 1

# 3. Add tasks one at a time as you discover them
upsert_task {"list_id": 1, "content": "Research JWT", "priority": 1}
# -> ID: 1
upsert_task {"list_id": 1, "content": "Implement login", "priority": 1}
# -> ID: 2
upsert_task {"list_id": 1, "content": "Write tests", "priority": 2}
# -> ID: 3

# 4. Break down complex tasks with subtasks
upsert_task {"list_id": 1, "parent_id": 2, "content": "Add /login endpoint"}
upsert_task {"list_id": 1, "parent_id": 2, "content": "Add password validation"}

# 5. Track progress - update status via upsert_task
upsert_task {"list_id": 1, "task_id": 1, "status": "done"}

# Add progress notes to the list
upsert_task_list {"list_id": 1, "notes": "Decided on jsonwebtoken crate"}

# 6. Complete remaining tasks
complete_task {"list_id": 1, "task_id": 2}
complete_task {"list_id": 1, "task_id": 3}

# 7. Create reference notes
upsert_note {"title": "JWT Best Practices", "content": "...", "tags": ["security"]}

# 8. Search later
search {"query": "jwt AND security"}

# 9. Backup your work
export_data {}
```

## Notes

- Database auto-initializes on first tool call
- Repository must be registered before creating lists/notes
- IDs are 8-character hex strings (e.g., `a1b2c3d4`)
- Tags stored as JSON arrays
- Timestamps in ISO format
- All markdown content preserved as-is
- SQL injection protected (single quote escaping)
- Sync auto-refreshes on MCP startup (if configured)
