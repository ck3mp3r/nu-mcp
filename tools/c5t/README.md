# c5t - Context/Memory Management Tool

Context preservation across LLM sessions using SQLite and Nushell.

## Overview

c5t (Context) helps LLMs maintain state across sessions by providing:
- **Todo Lists**: Kanban-style task tracking with 6 statuses
- **Notes**: Persistent markdown documentation
- **Auto-Archive**: Completed todo lists become searchable notes
- **Full-Text Search**: FTS5 search with boolean operators
- **Session Notes**: Use tag 'session' for context that persists across conversations

## Quick Start

The tool auto-initializes on first use. Database stored at `.c5t/context.db`.

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

# When all items done → auto-archives as note
```

**Statuses**: `backlog`, `todo`, `in_progress`, `review`, `done`, `cancelled`

**Timestamps** (auto-managed):
- `created_at`: Set when item is created
- `started_at`: Set when item moves to `in_progress` status
- `completed_at`: Set when item moves to `done` or `cancelled` status

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

**Note Types**: `manual`, `archived_todo`

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

### Todo Lists
- `c5t_upsert_list` - Create or update a list (omit list_id to create, provide to update). Supports name, description, tags, and progress notes.
- `c5t_list_active` - List active lists
- `c5t_get_list` - Get list metadata without items
- `c5t_delete_list` - Remove a list (use force=true if has items)
- `c5t_archive_list` - Manually archive a list
- `c5t_upsert_item` - Create or update an item (omit item_id to create, provide to update). Can set content, priority, status.
- `c5t_list_items` - View list with items grouped by status
- `c5t_list_active_items` - View only active items
- `c5t_complete_item` - Mark item done (shortcut for status='done')
- `c5t_delete_item` - Remove an item
- `c5t_move_item` - Move item to another list

### Notes
- `c5t_upsert_note` - Create or update a note (omit note_id to create, provide to update)
- `c5t_list_notes` - List notes, filter by tags or type
- `c5t_get_note` - Get specific note by ID
- `c5t_delete_note` - Remove a note
- `c5t_search` - Full-text search with FTS5

### Summary
- `c5t_get_summary` - Quick status overview of active work

### Data Management
- `c5t_export_data` - Export all data to `.c5t/backup-{timestamp}.json`
- `c5t_list_backups` - List available backup files
- `c5t_import_data` - Import data from backup file (merge or replace)

## Auto-Archive

When all items in a todo list are completed (status `done` or `cancelled`), the list is automatically:
1. Archived (status changed to `archived`)
2. Converted to a markdown note with:
   - List name, description, tags
   - All completed items with timestamps
   - Progress notes
   - Source list ID for reference

Archived notes are searchable and appear in `c5t_list_notes` with type `archived_todo`.

## Database

- **Location**: `.c5t/context.db`
- **Schema**: SQLite with INTEGER PRIMARY KEYs
- **Tables**: `todo_list`, `todo_item`, `note`, `note_fts` (FTS5)
- **Migration**: Auto-applies on initialization

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
c5t_upsert_list {"name": "Auth Feature", "tags": ["backend"]}
# → ID: 1

# 2. Add tasks one at a time as you discover them
c5t_upsert_item {"list_id": 1, "content": "Research JWT", "priority": 1}
c5t_upsert_item {"list_id": 1, "content": "Implement login", "priority": 1}
c5t_upsert_item {"list_id": 1, "content": "Write tests", "priority": 2}

# 3. Track progress - update status via upsert_item
c5t_upsert_item {"list_id": 1, "item_id": 1, "status": "done"}

# Add progress notes to the list
c5t_upsert_list {"list_id": 1, "notes": "Decided on jsonwebtoken crate"}

# 4. Complete remaining items one by one
c5t_complete_item {"list_id": 1, "item_id": 2}
c5t_complete_item {"list_id": 1, "item_id": 3}
# → Auto-archives as note when all done

# 5. Create reference notes
c5t_upsert_note {"title": "JWT Best Practices", "content": "...", "tags": ["security"]}

# 6. Search later
c5t_search {"query": "jwt AND security"}
```

## Notes

- Database auto-initializes on first tool call
- IDs are auto-generated integers (SQLite rowid)
- Tags stored as JSON arrays
- Timestamps in ISO format
- All markdown content preserved as-is
- SQL injection protected (single quote escaping)
