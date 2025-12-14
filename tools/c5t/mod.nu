# c5t (Context) Tool for nu-mcp - Context/memory management across sessions

# Import helper modules
use storage.nu *
use formatters.nu *
use utils.nu *

def main [] {
  help main
}

def "main list-tools" [] {
  init-database | ignore

  [
    {
      name: "create_list"
      description: "Create a new todo list to track work items. Supports statuses (backlog→todo→in_progress→review→done→cancelled), priorities 1-5, auto-archive when all items complete."
      input_schema: {
        type: "object"
        properties: {
          name: {
            type: "string"
            description: "Name of the todo list (e.g., 'Feature Implementation', 'Bug Fixes')"
          }
          description: {
            type: "string"
            description: "Brief description of what this list is for (optional)"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Tags to organize the list (e.g., ['backend', 'urgent']) (optional)"
          }
        }
        required: ["name"]
      }
    }
    {
      name: "list_active"
      description: "List all active todo lists, optionally filtered by tags"
      input_schema: {
        type: "object"
        properties: {
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Filter lists by tags - shows lists with ANY of these tags (optional)"
          }
        }
      }
    }
    {
      name: "add_item"
      description: "Add a todo item to a list. Defaults to 'backlog' status. Workflow: backlog→todo→in_progress→review→done→cancelled. Priority 1-5 where 5=critical."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list to add the item to"
          }
          content: {
            type: "string"
            description: "Description of the todo item"
          }
          priority: {
            type: "integer"
            description: "Priority level (1-5, where 5 is highest priority) (optional)"
            minimum: 1
            maximum: 5
          }
          status: {
            type: "string"
            description: "Initial status (defaults to 'backlog')"
            enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
          }
        }
        required: ["list_id" "content"]
      }
    }
    {
      name: "update_item_status"
      description: "Update item status (backlog→todo→in_progress→review→done→cancelled). Auto-sets started_at/completed_at timestamps. Auto-archives list when all items done/cancelled."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "integer"
            description: "ID of the item to update"
          }
          status: {
            type: "string"
            description: "New status for the item"
            enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
          }
        }
        required: ["list_id" "item_id" "status"]
      }
    }
    {
      name: "update_item_priority"
      description: "Update the priority of a todo item"
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "integer"
            description: "ID of the item to update"
          }
          priority: {
            type: "integer"
            description: "New priority level (1-5, where 5 is highest)"
            minimum: 1
            maximum: 5
          }
        }
        required: ["list_id" "item_id" "priority"]
      }
    }
    {
      name: "complete_item"
      description: "Mark item as complete (status='done'). Sets completed_at timestamp. Auto-archives list when this completes the last item."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "integer"
            description: "ID of the item to complete"
          }
        }
        required: ["list_id" "item_id"]
      }
    }
    {
      name: "list_items"
      description: "List all items in a todo list, optionally filtered by status"
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list"
          }
          status: {
            type: "string"
            description: "Filter by status (optional, or use 'active' to exclude done/cancelled)"
            enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled" "active"]
          }
        }
        required: ["list_id"]
      }
    }
    {
      name: "list_active_items"
      description: "List active items in a todo list (excludes 'done' and 'cancelled')"
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list"
          }
        }
        required: ["list_id"]
      }
    }
    {
      name: "update_notes"
      description: "Update the progress notes on a todo list (supports markdown)"
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list to update"
          }
          notes: {
            type: "string"
            description: "Markdown-formatted progress notes (can be empty to clear notes)"
          }
        }
        required: ["list_id" "notes"]
      }
    }
    {
      name: "create_note"
      description: "Create a standalone note with markdown content"
      input_schema: {
        type: "object"
        properties: {
          title: {
            type: "string"
            description: "Title of the note"
          }
          content: {
            type: "string"
            description: "Markdown-formatted content of the note"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Tags to organize the note (optional)"
          }
        }
        required: ["title" "content"]
      }
    }
    {
      name: "list_notes"
      description: "List notes with optional filtering by tags, type, and limit"
      input_schema: {
        type: "object"
        properties: {
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Filter notes by tags - shows notes with ANY of these tags (optional)"
          }
          note_type: {
            type: "string"
            description: "Filter by note type (optional)"
            enum: ["manual" "archived_todo" "scratchpad"]
          }
          limit: {
            type: "integer"
            description: "Maximum number of notes to return (optional, default: all)"
            minimum: 1
          }
        }
      }
    }
    {
      name: "get_note"
      description: "Get a specific note by ID"
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "integer"
            description: "ID of the note to retrieve"
          }
        }
        required: ["note_id"]
      }
    }
    {
      name: "search"
      description: "Search notes using FTS5 syntax. Examples: 'term', 'term1 AND term2', 'term1 OR term2', 'NOT term', '\"exact phrase\"', 'prefix*'. Searches title and content."
      input_schema: {
        type: "object"
        properties: {
          query: {
            type: "string"
            description: "FTS5 search query. Simple: 'keyword'. Boolean: 'term1 AND term2', 'term1 OR term2'. Exclude: 'NOT term'. Phrase: '\"exact phrase\"'. Prefix: 'term*'. Combine: 'api AND (error OR bug) NOT deprecated'"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Filter results by tags - shows notes with ANY of these tags (optional)"
          }
          limit: {
            type: "integer"
            description: "Maximum number of results to return (default: 10)"
            minimum: 1
            default: 10
          }
        }
        required: ["query"]
      }
    }
    {
      name: "update_scratchpad"
      description: "Update or create the scratchpad note for session context. Only one scratchpad exists. Best practice: Update at session milestones (every 3-5 changes, after major tasks). Use get_scratchpad at session start to review context."
      input_schema: {
        type: "object"
        properties: {
          content: {
            type: "string"
            description: "Markdown content for the scratchpad. Typically includes: active work summary, in-progress items, recent accomplishments, key decisions/learnings, next steps, and current timestamp. Use generate_scratchpad_draft to auto-generate a starting template."
          }
        }
        required: ["content"]
      }
    }
    {
      name: "get_scratchpad"
      description: "CONTEXT LOST? START HERE. Retrieve scratchpad with session context, active work, and recent progress. Use at session start or for context recovery. Returns markdown note or null if none exists."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "generate_scratchpad_draft"
      description: "Generate scratchpad draft with auto-populated facts (active lists, in-progress, completed, priorities). Review, add context/decisions, then call update_scratchpad."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "get_summary"
      description: "Get comprehensive overview: stats, active lists, in-progress items, high-priority items (P4-P5), recently completed, scratchpad status. Use at session start or for context recovery. Returns markdown summary."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
  ] | to json
}

def "main call-tool" [
  tool_name: string
  args: any = {}
] {
  let parsed_args = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  match $tool_name {
    "create_list" => {
      let validation = validate-list-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let name = $parsed_args.name
      let description = if "description" in $parsed_args { $parsed_args.description } else { null }
      let tags = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = create-todo-list $name $description $tags

      if not $result.success {
        return $result.error
      }

      format-list-created $result
    }

    "list_active" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = get-active-lists $tag_filter

      if not $result.success {
        return $result.error
      }

      format-active-lists $result.lists
    }

    "add_item" => {
      let validation = validate-item-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let list_id = $parsed_args.list_id
      let content = $parsed_args.content
      let priority = if "priority" in $parsed_args { $parsed_args.priority } else { null }
      let status = if "status" in $parsed_args { $parsed_args.status } else { null }

      # Validate priority if provided
      if $priority != null {
        let priority_validation = validate-priority $priority
        if not $priority_validation.valid {
          return $priority_validation.error
        }
      }

      # Validate status if provided
      if $status != null {
        let status_validation = validate-status $status
        if not $status_validation.valid {
          return $status_validation.error
        }
      }

      # Check if list exists
      if not (list-exists $list_id) {
        return $"Error: List not found: ($list_id)"
      }

      let result = add-todo-item $list_id $content $priority $status

      if not $result.success {
        return $result.error
      }

      format-item-created $result
    }

    "update_item_status" => {
      let validation = validate-item-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      if "status" not-in $parsed_args {
        return "Error: Missing required field: 'status'"
      }

      let list_id = $parsed_args.list_id
      let item_id = $parsed_args.item_id
      let status = $parsed_args.status

      # Validate status
      let status_validation = validate-status $status
      if not $status_validation.valid {
        return $status_validation.error
      }

      # Check if item exists
      if not (item-exists $list_id $item_id) {
        return $"Error: Item not found: ($item_id)"
      }

      let result = update-item-status $list_id $item_id $status

      if not $result.success {
        return $result.error
      }

      if $result.archived {
        format-item-updated-with-archive "status" $item_id $status $result.note_id
      } else {
        format-item-updated "status" $item_id $status
      }
    }

    "update_item_priority" => {
      let validation = validate-item-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      if "priority" not-in $parsed_args {
        return "Error: Missing required field: 'priority'"
      }

      let list_id = $parsed_args.list_id
      let item_id = $parsed_args.item_id
      let priority = $parsed_args.priority

      # Validate priority
      let priority_validation = validate-priority $priority
      if not $priority_validation.valid {
        return $priority_validation.error
      }

      # Check if item exists
      if not (item-exists $list_id $item_id) {
        return $"Error: Item not found: ($item_id)"
      }

      let result = update-item-priority $list_id $item_id $priority

      if not $result.success {
        return $result.error
      }

      format-item-updated "priority" $item_id $priority
    }

    "complete_item" => {
      let validation = validate-item-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let list_id = $parsed_args.list_id
      let item_id = $parsed_args.item_id

      # Check if item exists
      if not (item-exists $list_id $item_id) {
        return $"Error: Item not found: ($item_id)"
      }

      let result = update-item-status $list_id $item_id "done"

      if not $result.success {
        return $result.error
      }

      if $result.archived {
        format-item-completed-with-archive $item_id $result.note_id
      } else {
        format-item-completed $item_id
      }
    }

    "list_items" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id
      let status_filter = if "status" in $parsed_args { $parsed_args.status } else { null }

      # Validate status if provided
      if $status_filter != null and $status_filter != "active" {
        let status_validation = validate-status $status_filter
        if not $status_validation.valid {
          return $status_validation.error
        }
      }

      let result = get-list-with-items $list_id $status_filter

      if not $result.success {
        return $result.error
      }

      format-items-list $result.list $result.items
    }

    "list_active_items" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id

      let result = get-list-with-items $list_id "active"

      if not $result.success {
        return $result.error
      }

      format-items-list $result.list $result.items
    }

    "update_notes" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      if "notes" not-in $parsed_args {
        return "Error: Missing required field: 'notes'"
      }

      let list_id = $parsed_args.list_id
      let notes = $parsed_args.notes

      # Check if list exists
      if not (list-exists $list_id) {
        return $"Error: List not found: ($list_id)"
      }

      let result = update-todo-notes $list_id $notes

      if not $result.success {
        return $result.error
      }

      format-notes-updated $list_id
    }

    "create_note" => {
      let validation = validate-note-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let title = $parsed_args.title
      let content = $parsed_args.content
      let tags = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = create-note $title $content $tags

      if not $result.success {
        return $result.error
      }

      format-note-created-manual $result
    }

    "list_notes" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }
      let note_type = if "note_type" in $parsed_args { $parsed_args.note_type } else { null }
      let limit = if "limit" in $parsed_args { $parsed_args.limit } else { null }

      let result = get-notes $tag_filter $note_type $limit

      if not $result.success {
        return $result.error
      }

      format-notes-list-detailed $result.notes
    }

    "get_note" => {
      if "note_id" not-in $parsed_args {
        return "Error: Missing required field: 'note_id'"
      }

      let note_id = $parsed_args.note_id

      let result = get-note-by-id $note_id

      if not $result.success {
        return $result.error
      }

      format-note-detail $result.note
    }

    "search" => {
      if "query" not-in $parsed_args {
        return "Error: Missing required field: 'query'"
      }

      let query = $parsed_args.query
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { [] }
      let limit = if "limit" in $parsed_args { $parsed_args.limit } else { 10 }

      let result = search-notes $query --limit $limit --tags $tag_filter

      if not $result.success {
        return $result.error
      }

      format-search-results $result.notes
    }

    "update_scratchpad" => {
      if "content" not-in $parsed_args {
        return "Error: Missing required field: 'content'"
      }

      let content = $parsed_args.content

      let result = update-scratchpad $content

      if not $result.success {
        return $result.error
      }

      $"✅ Scratchpad updated \(ID: ($result.scratchpad_id)\)

Content preview:($content | lines | first 3 | str join (char newline))
..."
    }

    "get_scratchpad" => {
      let result = get-scratchpad

      if not $result.success {
        return $result.error
      }

      if $result.scratchpad == null {
        return "📝 No scratchpad exists yet. Create one with update_scratchpad."
      }

      format-note-detail $result.scratchpad
    }

    "generate_scratchpad_draft" => {
      # Get all the data we need
      let lists_result = get-active-lists-with-counts
      let in_progress_result = get-all-in-progress-items
      let completed_result = get-recently-completed-items
      let high_priority_result = get-high-priority-next-steps

      if not $lists_result.success {
        return $lists_result.error
      }
      if not $in_progress_result.success {
        return $in_progress_result.error
      }
      if not $completed_result.success {
        return $completed_result.error
      }
      if not $high_priority_result.success {
        return $high_priority_result.error
      }

      # Generate the template
      let draft = generate-scratchpad-template $lists_result.lists $in_progress_result.items $completed_result.items $high_priority_result.items

      $"📝 Scratchpad Draft Generated

Review the draft below, add your context/learnings/decisions in the marked sections, then call update_scratchpad with the enhanced content.

---($draft)"
    }

    "get_summary" => {
      let result = get-summary

      if not $result.success {
        return $result.error
      }

      format-summary $result.summary
    }

    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
