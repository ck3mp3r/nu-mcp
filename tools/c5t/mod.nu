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
      name: "c5t_create_list"
      description: "Create a new todo list to track work items and progress"
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
      name: "c5t_list_active"
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
      name: "c5t_add_item"
      description: "Add a todo item to an existing list"
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
      name: "c5t_update_item_status"
      description: "Update the status of a todo item (automatically manages started_at and completed_at timestamps)"
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
      name: "c5t_update_item_priority"
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
      name: "c5t_complete_item"
      description: "Mark a todo item as complete (shorthand for setting status to 'done')"
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
      name: "c5t_list_items"
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
      name: "c5t_list_active_items"
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
      name: "c5t_update_notes"
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
      name: "c5t_create_note"
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
      name: "c5t_list_notes"
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
      name: "c5t_get_note"
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
      name: "c5t_search"
      description: "Search notes using full-text search. Supports FTS5 query syntax: simple terms, boolean operators (AND, OR, NOT), phrases (\"exact match\"), and prefix matching (term*)"
      input_schema: {
        type: "object"
        properties: {
          query: {
            type: "string"
            description: "Search query. Examples: 'database', 'api AND database', '\"error handling\"', 'auth*'"
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
      name: "c5t_update_scratchpad"
      description: "Update or create the scratchpad note. Only one scratchpad exists - it will be created if it doesn't exist, or updated if it does. Use this to maintain an auto-updating context summary."
      input_schema: {
        type: "object"
        properties: {
          content: {
            type: "string"
            description: "Markdown content for the scratchpad. Typically includes active todos, recent notes, files being worked on, and current timestamp."
          }
        }
        required: ["content"]
      }
    }
    {
      name: "c5t_get_scratchpad"
      description: "Retrieve the current scratchpad note. Returns null if no scratchpad exists yet."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "c5t_generate_scratchpad_draft"
      description: "Generate a scratchpad draft with auto-populated facts (active lists, in-progress items, recently completed items, high-priority next steps). LLM should review, add context/learnings/decisions, then call c5t_update_scratchpad."
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
    "c5t_create_list" => {
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

    "c5t_list_active" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = get-active-lists $tag_filter

      if not $result.success {
        return $result.error
      }

      format-active-lists $result.lists
    }

    "c5t_add_item" => {
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

    "c5t_update_item_status" => {
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

    "c5t_update_item_priority" => {
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

    "c5t_complete_item" => {
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

    "c5t_list_items" => {
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

    "c5t_list_active_items" => {
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

    "c5t_update_notes" => {
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

    "c5t_create_note" => {
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

    "c5t_list_notes" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }
      let note_type = if "note_type" in $parsed_args { $parsed_args.note_type } else { null }
      let limit = if "limit" in $parsed_args { $parsed_args.limit } else { null }

      let result = get-notes $tag_filter $note_type $limit

      if not $result.success {
        return $result.error
      }

      format-notes-list-detailed $result.notes
    }

    "c5t_get_note" => {
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

    "c5t_search" => {
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

    "c5t_update_scratchpad" => {
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

    "c5t_get_scratchpad" => {
      let result = get-scratchpad

      if not $result.success {
        return $result.error
      }

      if $result.scratchpad == null {
        return "📝 No scratchpad exists yet. Create one with c5t_update_scratchpad."
      }

      format-note-detail $result.scratchpad
    }

    "c5t_generate_scratchpad_draft" => {
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

Review the draft below, add your context/learnings/decisions in the marked sections, then call c5t_update_scratchpad with the enhanced content.

---($draft)"
    }

    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
