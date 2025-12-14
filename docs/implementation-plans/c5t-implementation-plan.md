# c5t (Context) Tool Implementation Plan

## Overview

- **Purpose**: Context/memory management tool to preserve context across sessions, track work via todo lists, and store knowledge in notes. Addresses context loss in LLM continuation summaries.
- **Target Users**: Developers working on projects with nu-mcp, especially across multiple sessions
- **External Dependencies**: SQLite (via Nushell's built-in `query db` command)

## Problem Statement

OpenCode's context continuation summaries can lose critical details:
- File/directory locations where work is happening
- Architectural decisions and their reasoning
- Work progress and what's pending
- Project-specific patterns and gotchas

This causes developers to re-search for files, re-explain context, and lose momentum when resuming work.

## Goals

1. **Todo List Management**: Track work items and progress
2. **Auto-Archive**: Completed todo lists automatically become notes
3. **Markdown Notes**: Store knowledge with rich formatting
4. **Scratchpad**: Auto-update context snapshot every 25% token usage
5. **Search**: Find past decisions and knowledge
6. **Per-Project Storage**: Each project has its own `.c5t/context.db`

## Capabilities

- [ ] Create todo lists with items
- [ ] Mark items complete, auto-archive when all done
- [ ] Update progress notes on todo lists (markdown)
- [ ] Create standalone notes (markdown)
- [ ] Search notes by tags and full-text
- [ ] Scratchpad for session context preservation
- [ ] List active todos and archived notes

## Module Structure

- `mod.nu`: MCP interface and tool routing
- `storage.nu`: SQLite database operations (CRUD)
- `formatters.nu`: Output formatting for MCP responses
- `utils.nu`: ID generation, validation, helpers
- `README.md`: User documentation

## Database Schema

### Design Philosophy: Kanban-Ready

The schema supports Kanban-style workflow with multiple item statuses. The MVP will implement basic statuses (todo, in_progress, done), but the schema is designed to support full Kanban visualization in future iterations.

**Todo Item Statuses:**
- `backlog`: Planned but not prioritized (future)
- `todo`: Ready to work on (MVP)
- `in_progress`: Currently being worked on (MVP)
- `review`: Awaiting review/validation (future)
- `done`: Completed successfully (MVP)
- `cancelled`: No longer needed (MVP)

**Future Enhancements:**
- Visual Kanban board rendering (columns view)
- `c5t_move_item` tool to transition between statuses
- `c5t_get_board` tool to visualize items grouped by status
- Position/ordering within status columns
- WIP (Work In Progress) limits per status

### Tables

```sql
-- Todo List
CREATE TABLE IF NOT EXISTS todo_list (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    notes TEXT,                    -- Progress notes (markdown)
    tags TEXT,                     -- JSON array: ["tag1", "tag2"]
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    archived_at TEXT
);

-- Todo Item
CREATE TABLE IF NOT EXISTS todo_item (
    id TEXT PRIMARY KEY,
    list_id TEXT NOT NULL,
    content TEXT NOT NULL,
    status TEXT DEFAULT 'todo' CHECK(status IN ('backlog', 'todo', 'in_progress', 'review', 'done', 'cancelled')),
    position INTEGER DEFAULT 0,   -- Order within status column (for future Kanban view)
    created_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,              -- When moved to in_progress
    completed_at TEXT,            -- When moved to done
    FOREIGN KEY (list_id) REFERENCES todo_list(id) ON DELETE CASCADE
);

-- Note (archived todos + standalone notes + scratchpad)
CREATE TABLE IF NOT EXISTS note (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,         -- Markdown content
    tags TEXT,                     -- JSON array
    note_type TEXT DEFAULT 'manual' CHECK(note_type IN ('manual', 'archived_todo', 'scratchpad')),
    source_id TEXT,                -- Original todo list ID if archived
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_todo_list_status ON todo_list(status);
CREATE INDEX IF NOT EXISTS idx_todo_item_list ON todo_item(list_id);
CREATE INDEX IF NOT EXISTS idx_todo_item_status ON todo_item(status);  -- For Kanban queries
CREATE INDEX IF NOT EXISTS idx_todo_item_list_status ON todo_item(list_id, status);  -- Combined for filtering
CREATE INDEX IF NOT EXISTS idx_note_type ON note(note_type);

-- Full-text search
CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
    title,
    content,
    content=note,
    content_rowid=id
);

-- FTS sync triggers
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

-- Auto-update timestamps
CREATE TRIGGER IF NOT EXISTS todo_list_update AFTER UPDATE ON todo_list BEGIN
    UPDATE todo_list SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS note_update AFTER UPDATE ON note BEGIN
    UPDATE note SET updated_at = datetime('now') WHERE id = NEW.id;
END;
```

## Context7 Research

- [x] Research Nushell SQLite integration (built-in `query db`)
- [x] Research markdown handling in Nushell
- [ ] Research existing note-taking tool patterns (Obsidian, Notion)

## Security Considerations

- **No safety modes needed**: This tool manages local project data only
- **No sensitive data**: All data is project-specific context
- **File permissions**: Database stored in `.c5t/` (can be gitignored)

## Implementation Milestones

### Milestone 1: Basic Structure & Database
**Goal**: Set up tool skeleton and SQLite database initialization

**Tasks**:
- [ ] Create `tools/c5t/` directory structure
- [ ] Create `mod.nu` skeleton with `list-tools` and `call-tool`
- [ ] Create `storage.nu` with database initialization
- [ ] Implement schema creation (SQL above)
- [ ] Create `utils.nu` with ID generation
- [ ] Create `formatters.nu` stub
- [ ] Test database creation

**Validation**:
```bash
nu tools/c5t/mod.nu list-tools | from json
# Should return empty array

ls .c5t/context.db
# Database file should exist with correct schema
```

**Acceptance Criteria**:
- [ ] Tool discovered by nu-mcp
- [ ] Database created in `.c5t/context.db`
- [ ] Schema created successfully
- [ ] All tables and triggers exist

---

### Milestone 2: Todo List Creation
**Goal**: Create and list todo lists

**Tools to Implement**:
- `c5t_create_list` - Create new todo list
- `c5t_list_active` - Show all active todo lists

**Functions** (storage.nu, kebab-case):
- `init-database` - Ensure DB and schema exist
- `create-todo-list [name, description, tags]`
- `get-active-lists [tag_filter?]`
- `generate-id` - Unique ID generation

**Validation**:
```bash
nu tools/c5t/mod.nu call-tool c5t_create_list '{
  "name": "Test Feature",
  "description": "Testing c5t",
  "tags": ["test"]
}'

nu tools/c5t/mod.nu call-tool c5t_list_active '{}'
# Should show the created list
```

**Acceptance Criteria**:
- [x] Can create todo list with name, description, tags
- [x] List shows active todo lists
- [x] Tags stored as JSON array
- [x] Created_at timestamp set automatically
- [x] Status defaults to 'active'
- [x] SOLID principles applied (execute-sql, query-sql abstractions)
- [x] All tests passing (41/41)

**Status**: ✅ COMPLETE (commit 19f3b8f)

---

### Milestone 3: Todo Items Management
**Goal**: Add and manage todo items with status transitions

**Tools Implemented**:
- `c5t_add_item` - Add item to list (defaults to 'backlog' status)
- `c5t_update_item_status` - Change item status with automatic timestamp management
- `c5t_update_item_priority` - Update item priority (1-5 scale)
- `c5t_complete_item` - Shortcut to mark item as 'done'
- `c5t_list_items` - List items with optional status filter
- `c5t_list_active_items` - List only active items (excludes done/cancelled)

**Functions Implemented** (storage.nu, kebab-case):
- `add-todo-item [list_id, content, priority?, status?]` - Status defaults to 'backlog', priority optional (1-5)
- `update-item-status [list_id, item_id, new_status]` - Automatic timestamp management (started_at, completed_at)
- `update-item-priority [list_id, item_id, priority]` - Update priority (1-5 or null)
- `get-list-with-items [list_id, status_filter?]` - Get list with items, optional filter ('active', or specific status)
- `get-item [list_id, item_id]` - Get single item
- `list-exists [list_id]` - Check if list exists
- `item-exists [list_id, item_id]` - Check if item exists

**Validation Functions** (utils.nu):
- `validate-status [status]` - Validates against allowed statuses
- `validate-priority [priority]` - Validates 1-5 range
- `validate-item-update-input [args]` - Validates list_id and item_id fields

**Timestamp Automation**:
- Moving to `in_progress`: Sets `started_at` if null
- Moving to `done` or `cancelled`: Sets `completed_at`
- Moving from `done`/`cancelled` to `backlog`/`todo`: Clears both timestamps
- Moving from `in_progress` to `backlog`/`todo`: Clears `started_at`

**Status Transitions**:
- Flexible (any-to-any) - no strict validation
- Supports: `backlog`, `todo`, `in_progress`, `review`, `done`, `cancelled`

**Acceptance Criteria**:
- [x] Can add items to existing list (default status: 'backlog')
- [x] Can update item status (flexible transitions)
- [x] Can update item priority (1-5 scale, nullable)
- [x] Can mark items complete with shortcut
- [x] completed_at timestamp set when status becomes 'done' or 'cancelled'
- [x] started_at timestamp set when status becomes 'in_progress'
- [x] Timestamps cleared when moving back to backlog/todo
- [x] List shows items grouped by status with priority ordering
- [x] Can filter items by status or show only active items
- [x] All validation working (status, priority, existence checks)
- [x] 58 tests passing (43 original + 15 new tests)

**Status**: ✅ COMPLETE (commit pending)

---

### Milestone 4: Progress Notes on Todo Lists
**Goal**: Update progress notes on todo lists

**Tools Implemented**:
- `c5t_update_notes` - Update notes field on list (supports markdown)

**Functions Implemented** (storage.nu, kebab-case):
- `update-todo-notes [list_id, notes]` - Update notes field with SQL escaping

**Formatter Added**:
- `format-notes-updated [list_id]` - Confirmation message for notes update

**Modified Functions**:
- `get-active-lists` - Now includes notes field in SELECT query
- `format-active-lists` - Displays notes if present

**Validation**:
```bash
nu tools/c5t/mod.nu call-tool c5t_update_notes '{
  "list_id": "...",
  "notes": "## Progress\n\nCompleted schema, working on CRUD operations"
}'
```

**Acceptance Criteria**:
- [x] Can update notes field with markdown
- [x] Notes preserved as-is (no markdown rendering)
- [x] Updated_at timestamp changes automatically (database trigger)
- [x] Notes visible in list_active output
- [x] 61 tests passing (58 from M3 + 3 new tests)

**Status**: ✅ COMPLETE (commit pending)

---

### Milestone 5: Auto-Archive Logic
**Goal**: Automatically archive completed todo lists as notes

**Functions Implemented** (storage.nu, kebab-case):
- `generate-archive-note [todo_list, items]` - Creates formatted markdown from list and items
- `all-items-completed [list_id]` - Checks if all items are done/cancelled
- `archive-todo-list [list_id]` - Creates note and archives list
- Modified `update-item-status` - Triggers auto-archive when last item completes

**Formatters Added**:
- `format-item-updated-with-archive` - Shows archive confirmation with status update
- `format-item-completed-with-archive` - Shows archive confirmation with completion

**Archive Note Content**:
```markdown
# <todo list name>

<todo list description>

## Completed Items
- ✅ <item content> (completed: <timestamp>)  # done items
- ❌ <item content> (completed: <timestamp>)  # cancelled items

## Progress Notes
<todo list notes field>

---
*Auto-archived on <timestamp>*
```

**Auto-Archive Trigger**:
- When `update-item-status` or `complete-item` changes last pending item to done/cancelled
- Checks if all items completed using COUNT(*) query
- Creates note with `note_type='archived_todo'`
- Updates list: `status='archived'`, sets `archived_at` timestamp
- User sees special message with note ID

**Bug Fixes**:
- Disabled FTS (full-text search) until Milestone 7 - TEXT IDs incompatible with FTS rowid
- Fixed empty list handling in `get-active-lists`
- Added `notes` field to `get-list-with-items` SELECT query
- Escaped parentheses and asterisk in SQL strings for Nushell parsing

**Acceptance Criteria**:
- [x] When last item completes, list auto-archives
- [x] Note created with note_type='archived_todo'
- [x] Note content includes all completed items with timestamps and emojis
- [x] Note content includes description and progress notes
- [x] Source_id points to original todo list ID
- [x] Todo list status changes to 'archived'
- [x] Archived_at timestamp set automatically
- [x] Archived lists don't appear in c5t_list_active
- [x] Tags preserved from list to note
- [x] 64 tests passing (61 from M4 + 3 new tests)

**Status**: ✅ COMPLETE (commit pending)

---

### Milestone 6: Standalone Notes
**Goal**: Create and manage manual notes

**Tools to Implement**:
- `c5t_create_note` - Create standalone note
- `c5t_list_notes` - List notes with filtering
- `c5t_get_note` - Get specific note by ID

**Functions** (storage.nu, kebab-case):
- `create-note [title, content, tags]`
- `get-notes [tag_filter?, note_type?, limit?]`
- `get-note-by-id [note_id]`

**Validation**:
```bash
nu tools/c5t/mod.nu call-tool c5t_create_note '{
  "title": "Database Design Decision",
  "content": "# Why SQLite\n\nChose SQLite for...",
  "tags": ["architecture", "database"]
}'

nu tools/c5t/mod.nu call-tool c5t_list_notes '{
  "tags": ["architecture"],
  "limit": 10
}'
```

**Acceptance Criteria**:
- [ ] Can create notes with markdown content
- [ ] Can list notes with tag filtering
- [ ] Can retrieve specific note by ID
- [ ] Note_type defaults to 'manual'
- [ ] Timestamps set correctly

---

### Milestone 7: Full-Text Search
**Goal**: Search notes by content and title

**Tools to Implement**:
- `c5t_search` - Full-text search using FTS5

**Functions** (storage.nu, kebab-case):
- `search-notes [query, tag_filter?, limit?]`

**Validation**:
```bash
nu tools/c5t/mod.nu call-tool c5t_search '{
  "query": "database",
  "limit": 10
}'

nu tools/c5t/mod.nu call-tool c5t_search '{
  "query": "authentication",
  "tags": ["backend"]
}'
```

**Acceptance Criteria**:
- [ ] FTS5 full-text search works
- [ ] Searches both title and content
- [ ] Can combine with tag filtering
- [ ] Results sorted by relevance
- [ ] Limit parameter works

---

### Milestone 8: Scratchpad
**Goal**: Auto-updating context scratchpad

**Tools to Implement**:
- `c5t_update_scratchpad` - Update scratchpad note
- `c5t_get_scratchpad` - Retrieve current scratchpad

**Scratchpad Logic**:
- Single note with note_type='scratchpad'
- Updated at 25%, 50%, 75% context usage
- Contains:
  - Active todo lists summary
  - Recent notes (last 5)
  - Files being worked on
  - Current timestamp

**Functions** (storage.nu, kebab-case):
- `update-scratchpad [content]`
- `get-scratchpad`
- `generate-scratchpad-content` - Build scratchpad from current state

**Validation**:
```bash
# Manual test of scratchpad update
nu tools/c5t/mod.nu call-tool c5t_update_scratchpad '{
  "content": "## Current Work\n\n..."
}'

nu tools/c5t/mod.nu call-tool c5t_get_scratchpad '{}'
```

**Acceptance Criteria**:
- [ ] Only one scratchpad note exists
- [ ] Update replaces previous scratchpad
- [ ] Scratchpad has note_type='scratchpad'
- [ ] Content includes active todos + recent notes
- [ ] Timestamp shows last update

**Open Question**: How to detect 25% context usage?
- Manual trigger for MVP? (user calls `c5t_update_scratchpad`)
- Future: Hook into OpenCode's context tracking?

---

### Milestone 9: Formatters & Output
**Goal**: User-friendly output formatting

**Functions** (formatters.nu, kebab-case):
- `format-todo-created [list]`
- `format-todos-list [lists]`
- `format-note-created [note]`
- `format-notes-list [notes]`
- `format-search-results [notes]`

**Acceptance Criteria**:
- [ ] Todo lists show progress (e.g., "3/5 items complete")
- [ ] Notes show title, tags, preview
- [ ] Search results show matched snippets
- [ ] Timestamps formatted for readability
- [ ] Markdown content displayed appropriately

---

### Milestone 10: Error Handling & Validation
**Goal**: Robust error handling and input validation

**Functions** (utils.nu, kebab-case):
- `validate-list-input [args]`
- `validate-item-input [args]`
- `validate-note-input [args]`

**Error Scenarios**:
- [ ] Todo list not found
- [ ] Todo item not found
- [ ] Invalid list_id format
- [ ] Empty title/name
- [ ] Invalid tags format
- [ ] Database not initialized

**Acceptance Criteria**:
- [ ] Clear error messages for all failure cases
- [ ] Input validation before database operations
- [ ] Helpful suggestions in error messages
- [ ] Try-catch around all database operations

---

### Milestone 11: Documentation
**Goal**: Complete README and usage examples

**Files to Create**:
- [ ] `tools/c5t/README.md`

**Documentation Sections**:
- Tool overview and purpose
- Installation (auto-discovered by nu-mcp)
- Configuration (none needed for MVP)
- Available tools with examples
- Todo workflow example
- Notes workflow example
- Scratchpad usage
- Search examples
- Database location and structure
- FAQ and troubleshooting

**Acceptance Criteria**:
- [ ] README complete with all sections
- [ ] Code examples tested and working
- [ ] Clear explanation of auto-archive
- [ ] Scratchpad explained

---

### Milestone 12: Testing & Polish
**Goal**: Comprehensive testing and code quality

**Testing Scenarios**:
1. **Todo Lists**:
   - [ ] Create → Add items → Complete all → Verify archive
   - [ ] Multiple lists with different tags
   - [ ] Update notes field multiple times
   
2. **Notes**:
   - [ ] Create manual note with markdown
   - [ ] List with tag filtering
   - [ ] Search across notes
   - [ ] Retrieve archived todo as note
   
3. **Scratchpad**:
   - [ ] Update scratchpad multiple times
   - [ ] Retrieve scratchpad
   - [ ] Only one scratchpad exists
   
4. **Edge Cases**:
   - [ ] Empty database
   - [ ] Invalid IDs
   - [ ] Duplicate operations
   - [ ] Database corruption recovery

**Code Quality**:
- [ ] Format all Nushell files with topiary
- [ ] Run clippy and fix warnings
- [ ] Follow naming conventions (snake_case tools, kebab-case functions)
- [ ] Add comments for complex logic

---

## Tool Schemas (MCP)

### Todo Management

**c5t_create_list**:
```nushell
{
    name: "c5t_create_list"
    description: "Create a new todo list to track work"
    input_schema: {
        type: "object"
        properties: {
            name: { type: "string", description: "List name" }
            description: { type: "string", description: "Brief description" }
            tags: { 
                type: "array", 
                items: { type: "string" },
                description: "Tags for categorization"
            }
        }
        required: ["name"]
    }
}
```

**c5t_add_item**:
```nushell
{
    name: "c5t_add_item"
    description: "Add a todo item to a list (defaults to 'todo' status)"
    input_schema: {
        type: "object"
        properties: {
            list_id: { type: "string", description: "Todo list ID" }
            content: { type: "string", description: "Item description" }
            status: { 
                type: "string", 
                enum: ["backlog", "todo", "in_progress", "review", "done", "cancelled"],
                description: "Initial status (default: 'todo')" 
            }
        }
        required: ["list_id", "content"]
    }
}
```

**c5t_update_item_status**:
```nushell
{
    name: "c5t_update_item_status"
    description: "Update todo item status (e.g., todo → in_progress → done)"
    input_schema: {
        type: "object"
        properties: {
            list_id: { type: "string", description: "Todo list ID" }
            item_id: { type: "string", description: "Item ID" }
            status: {
                type: "string",
                enum: ["backlog", "todo", "in_progress", "review", "done", "cancelled"],
                description: "New status for the item"
            }
        }
        required: ["list_id", "item_id", "status"]
    }
}
```

**c5t_complete_item**:
```nushell
{
    name: "c5t_complete_item"
    description: "Mark item as done (shortcut for status='done'). Auto-archives list if all items done."
    input_schema: {
        type: "object"
        properties: {
            list_id: { type: "string", description: "Todo list ID" }
            item_id: { type: "string", description: "Item ID" }
        }
        required: ["list_id", "item_id"]
    }
}
```

**c5t_update_notes**:
```nushell
{
    name: "c5t_update_notes"
    description: "Update progress notes on a todo list (markdown supported)"
    input_schema: {
        type: "object"
        properties: {
            list_id: { type: "string", description: "Todo list ID" }
            notes: { type: "string", description: "Progress notes (markdown)" }
        }
        required: ["list_id", "notes"]
    }
}
```

**c5t_list_active**:
```nushell
{
    name: "c5t_list_active"
    description: "List all active todo lists"
    input_schema: {
        type: "object"
        properties: {
            tags: {
                type: "array",
                items: { type: "string" },
                description: "Filter by tags (optional)"
            }
        }
    }
}
```

### Notes Management

**c5t_create_note**:
```nushell
{
    name: "c5t_create_note"
    description: "Create a standalone note (markdown supported)"
    input_schema: {
        type: "object"
        properties: {
            title: { type: "string", description: "Note title" }
            content: { type: "string", description: "Note content (markdown)" }
            tags: {
                type: "array",
                items: { type: "string" },
                description: "Tags (optional)"
            }
        }
        required: ["title", "content"]
    }
}
```

**c5t_list_notes**:
```nushell
{
    name: "c5t_list_notes"
    description: "List notes with filtering"
    input_schema: {
        type: "object"
        properties: {
            tags: {
                type: "array",
                items: { type: "string" },
                description: "Filter by tags"
            }
            note_type: {
                type: "string",
                enum: ["manual", "archived_todo", "scratchpad", "all"],
                description: "Filter by type (default: all except scratchpad)"
            }
            limit: {
                type: "integer",
                minimum: 1,
                maximum: 100,
                description: "Max notes to return (default: 20)"
            }
        }
    }
}
```

**c5t_get_note**:
```nushell
{
    name: "c5t_get_note"
    description: "Get a specific note by ID"
    input_schema: {
        type: "object"
        properties: {
            note_id: { type: "string", description: "Note ID" }
        }
        required: ["note_id"]
    }
}
```

**c5t_search**:
```nushell
{
    name: "c5t_search"
    description: "Full-text search in notes"
    input_schema: {
        type: "object"
        properties: {
            query: { type: "string", description: "Search query" }
            tags: {
                type: "array",
                items: { type: "string" },
                description: "Also filter by tags (optional)"
            }
            limit: {
                type: "integer",
                minimum: 1,
                maximum: 100,
                description: "Max results (default: 20)"
            }
        }
        required: ["query"]
    }
}
```

### Scratchpad

**c5t_update_scratchpad**:
```nushell
{
    name: "c5t_update_scratchpad"
    description: "Update the session scratchpad (for context preservation)"
    input_schema: {
        type: "object"
        properties: {
            content: { type: "string", description: "Scratchpad content (markdown)" }
        }
        required: ["content"]
    }
}
```

**c5t_get_scratchpad**:
```nushell
{
    name: "c5t_get_scratchpad"
    description: "Get the current scratchpad content"
    input_schema: {
        type: "object"
        properties: {}
    }
}
```

## Testing Approach

### Manual Testing Commands

```bash
# Test database creation
nu tools/c5t/mod.nu list-tools

# Test todo workflow
nu tools/c5t/mod.nu call-tool c5t_create_list '{"name": "Test", "tags": ["test"]}'
nu tools/c5t/mod.nu call-tool c5t_add_item '{"list_id": "...", "content": "Item 1"}'
nu tools/c5t/mod.nu call-tool c5t_complete_item '{"list_id": "...", "item_id": "..."}'
nu tools/c5t/mod.nu call-tool c5t_list_active '{}'

# Test notes
nu tools/c5t/mod.nu call-tool c5t_create_note '{
  "title": "Test Note",
  "content": "# Test\n\nContent",
  "tags": ["test"]
}'
nu tools/c5t/mod.nu call-tool c5t_search '{"query": "test"}'

# Test scratchpad
nu tools/c5t/mod.nu call-tool c5t_update_scratchpad '{"content": "## Session\n\nWorking on..."}'
nu tools/c5t/mod.nu call-tool c5t_get_scratchpad '{}'
```

### Edge Cases to Test

- [ ] Create list without tags
- [ ] Add item to non-existent list
- [ ] Complete already completed item
- [ ] Complete item in archived list
- [ ] Search with no results
- [ ] List notes from empty database
- [ ] Update scratchpad multiple times (should replace)

## Questions & Decisions

### Database Location
**Decision**: Use `.c5t/context.db` in project root (per-project storage)
**Rationale**: Context is project-specific; separate databases prevent mixing unrelated work

### Auto-Archive Trigger
**Decision**: Automatically archive when last item is completed
**Rationale**: Simplifies workflow; completed work becomes searchable knowledge immediately

### Scratchpad Updates
**Question**: How to trigger at 25% context intervals?
**MVP Decision**: Manual trigger via `c5t_update_scratchpad`
**Future**: Hook into OpenCode's context tracking if API available

### Export/Import
**Decision**: Defer to future iteration
**Rationale**: Focus on core workflow first; export/import needed for backup/sync but not MVP

### Markdown Rendering
**Decision**: Store as-is, no rendering in tool output
**Rationale**: MCP clients may render markdown; tool just preserves format

### Tag Storage
**Decision**: JSON array as TEXT in SQLite
**Rationale**: Simple, queryable with SQLite JSON functions, easy to export

## Success Criteria

- [ ] Can create and manage todo lists
- [ ] Auto-archive works when all items complete
- [ ] Can create and search markdown notes
- [ ] Scratchpad updates and retrieves correctly
- [ ] Full-text search works across notes
- [ ] Database persists across sessions
- [ ] All tests pass
- [ ] Documentation complete
- [ ] Code formatted with topiary

## Timeline Estimate

- Milestone 1 (Structure & DB): 30 minutes
- Milestone 2 (Create Lists): 30 minutes
- Milestone 3 (Items): 30 minutes
- Milestone 4 (Notes Update): 15 minutes
- Milestone 5 (Auto-Archive): 45 minutes
- Milestone 6 (Standalone Notes): 30 minutes
- Milestone 7 (Search): 30 minutes
- Milestone 8 (Scratchpad): 30 minutes
- Milestone 9 (Formatters): 30 minutes
- Milestone 10 (Error Handling): 30 minutes
- Milestone 11 (Documentation): 30 minutes
- Milestone 12 (Testing): 45 minutes

**Total**: ~6 hours

## Future Enhancements (Post-MVP)

### Kanban Visualization
- `c5t_get_board` - Visualize items as Kanban board with columns
- `c5t_move_item` - Move items between status columns
- ASCII/Unicode board rendering for CLI display
- WIP limits per status column
- Drag-and-drop position ordering within columns
- Swimlanes (group by tag or priority)

### Data Management
- Export to JSON (with markdown content)
- Import from JSON exports
- Backup and restore functionality

### Note Enhancements
- Links between notes (Obsidian-style `[[note-title]]`)
- Backlinks (what references this note?)
- Note templates
- Attachments/file references

### Workflow
- Batch operations (archive multiple lists)
- Statistics (completion rates, velocity, etc.)
- Integration with TodoWrite tool
- Recurring tasks
- Due dates and reminders

## References

- Nushell SQLite Documentation: https://www.nushell.sh/book/loading_data.html
- SQLite FTS5: https://www.sqlite.org/fts5.html
- Tool Development Guide: `docs/tool-development.md`
- ArgoCD Implementation Plan (reference): `docs/implementation-plans/argocd-cli-auth.md`
