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
# Create a list
c5t_create_list {"name": "API Feature", "tags": ["backend", "urgent"]}
# → ID: 1

# Add items
c5t_add_item {"list_id": 1, "content": "Research JWT", "priority": 1}
c5t_add_item {"list_id": 1, "content": "Implement login"}

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
# Create note
c5t_create_note {
  "title": "Architecture Decision",
  "content": "We decided to use Rust for performance",
  "tags": ["architecture", "backend"]
}

# List notes (excludes scratchpad by default)
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
c5t_create_note {
  "title": "Session: Auth Feature - 2025-01-15",
  "content": "## Current Work\n\n- Working on auth feature\n- Next: rate limiting",
  "tags": ["session"]
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
- `c5t_create_list` - Create todo list
- `c5t_list_active` - List active lists
- `c5t_get_list` - Get list metadata without items
- `c5t_rename_list` - Change list name/description
- `c5t_delete_list` - Remove a list (use force=true if has items)
- `c5t_archive_list` - Manually archive a list
- `c5t_add_item` - Add item to list
- `c5t_bulk_add_items` - Add multiple items at once
- `c5t_list_items` - View list with items grouped by status
- `c5t_list_active_items` - View only active items
- `c5t_update_item_status` - Change item status
- `c5t_bulk_update_status` - Update multiple items' status at once
- `c5t_update_item_priority` - Set priority (1-5, where 1 is highest)
- `c5t_edit_item` - Update item content
- `c5t_complete_item` - Mark item done
- `c5t_delete_item` - Remove an item
- `c5t_move_item` - Move item to another list
- `c5t_update_notes` - Add/update progress notes on list

### Notes
- `c5t_create_note` - Create manual note (use tag 'session' for context notes)
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
c5t_create_list {"name": "Auth Feature", "tags": ["backend"]}
# → ID: 1

# 2. Add tasks
c5t_add_item {"list_id": 1, "content": "Research JWT", "priority": 1}
c5t_add_item {"list_id": 1, "content": "Implement login", "priority": 1}
c5t_add_item {"list_id": 1, "content": "Write tests", "priority": 2}

# 3. Track progress
c5t_update_item_status {"list_id": 1, "item_id": 1, "status": "done"}
c5t_update_notes {"list_id": 1, "notes": "Decided on jsonwebtoken crate"}

# 4. Complete remaining items
c5t_complete_item {"list_id": 1, "item_id": 2}
c5t_complete_item {"list_id": 1, "item_id": 3}
# → Auto-archives as note

# 5. Create reference notes
c5t_create_note {"title": "JWT Best Practices", "content": "...", "tags": ["security"]}

# 6. Search later
c5t_search {"query": "jwt AND security"}

# 7. Update scratchpad
c5t_update_scratchpad {"content": "## Current Context\n\n- Auth feature complete\n- Next: rate limiting"}
```

## Notes

- Database auto-initializes on first tool call
- IDs are auto-generated integers (SQLite rowid)
- Tags stored as JSON arrays
- Timestamps in ISO format
- All markdown content preserved as-is
- SQL injection protected (single quote escaping)
