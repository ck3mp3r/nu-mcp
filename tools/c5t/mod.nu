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
      description: "Track todos with full context: searchable history, auto-archive completed work, never lose progress across sessions. Supports 6 statuses, priorities 1-5, tags, and auto-timestamps."
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
      description: "SHOW TO USER. See all your active work at a glance."
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
      description: "Add a todo with auto-timestamps. 6 statuses (backlog→todo→in_progress→review→done→cancelled), priority 1-5 (1=critical). Defaults to 'backlog'."
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
            description: "Priority level (1-5, where 1 is highest priority) (optional)"
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
      description: "Change todo priority (1=critical, 5=low)"
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
            description: "New priority level (1-5, where 1 is highest)"
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
      name: "delete_item"
      description: "Remove a todo item from a list permanently."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "integer"
            description: "ID of the item to delete"
          }
        }
        required: ["list_id" "item_id"]
      }
    }
    {
      name: "edit_item"
      description: "Update the content/description of a todo item."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "integer"
            description: "ID of the item to edit"
          }
          content: {
            type: "string"
            description: "New content/description for the item"
          }
        }
        required: ["list_id" "item_id" "content"]
      }
    }
    {
      name: "delete_list"
      description: "Remove a todo list. Use force=true to delete list with items, otherwise fails if list has items."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list to delete"
          }
          force: {
            type: "boolean"
            description: "If true, delete list even if it has items (default: false)"
          }
        }
        required: ["list_id"]
      }
    }
    {
      name: "delete_note"
      description: "Remove a note permanently by ID."
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "integer"
            description: "ID of the note to delete"
          }
        }
        required: ["note_id"]
      }
    }
    {
      name: "rename_list"
      description: "Change the name and/or description of a todo list."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list to rename"
          }
          name: {
            type: "string"
            description: "New name for the list"
          }
          description: {
            type: "string"
            description: "New description for the list (optional)"
          }
        }
        required: ["list_id" "name"]
      }
    }
    {
      name: "bulk_add_items"
      description: "Add multiple todo items to a list in one call. Each item can have content (required), priority (1-5), and status."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list to add items to"
          }
          items: {
            type: "array"
            description: "Array of items to add. Each item: {content: string, priority?: 1-5, status?: string}"
            items: {
              type: "object"
              properties: {
                content: {
                  type: "string"
                  description: "Description of the todo item"
                }
                priority: {
                  type: "integer"
                  description: "Priority level 1-5 (optional)"
                  minimum: 1
                  maximum: 5
                }
                status: {
                  type: "string"
                  description: "Initial status (optional, defaults to backlog)"
                  enum: ["backlog" "todo" "in_progress" "review"]
                }
              }
              required: ["content"]
            }
          }
        }
        required: ["list_id" "items"]
      }
    }
    {
      name: "move_item"
      description: "Move a todo item from one list to another."
      input_schema: {
        type: "object"
        properties: {
          source_list_id: {
            type: "integer"
            description: "ID of the list containing the item"
          }
          item_id: {
            type: "integer"
            description: "ID of the item to move"
          }
          target_list_id: {
            type: "integer"
            description: "ID of the list to move the item to"
          }
        }
        required: ["source_list_id" "item_id" "target_list_id"]
      }
    }
    {
      name: "bulk_update_status"
      description: "Update status for multiple items at once. Skips non-existent items."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list containing the items"
          }
          item_ids: {
            type: "array"
            items: {type: "integer"}
            description: "Array of item IDs to update"
          }
          status: {
            type: "string"
            description: "New status for all items"
            enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
          }
        }
        required: ["list_id" "item_ids" "status"]
      }
    }
    {
      name: "get_list"
      description: "SHOW TO USER. Get list metadata (name, description, tags, status) without items."
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
      name: "archive_list"
      description: "Manually archive a list (creates archive note). Works even if items aren't all complete."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list to archive"
          }
        }
        required: ["list_id"]
      }
    }
    {
      name: "export_data"
      description: "Export all c5t data (lists, items, notes) as JSON backup file. Saves to .c5t/backup-{timestamp}.json by default."
      input_schema: {
        type: "object"
        properties: {
          filename: {
            type: "string"
            description: "Custom backup filename (optional, defaults to backup-{timestamp}.json)"
          }
        }
      }
    }
    {
      name: "import_data"
      description: "Import c5t data from JSON backup file. Use merge=true to add to existing data, merge=false to replace all. Use list_backups to see available files."
      input_schema: {
        type: "object"
        properties: {
          filename: {
            type: "string"
            description: "Backup filename in .c5t/ directory (e.g., 'backup-20251215-120000.json')"
          }
          merge: {
            type: "boolean"
            description: "If true, merge with existing data; if false (default), replace all data"
          }
        }
        required: ["filename"]
      }
    }
    {
      name: "list_backups"
      description: "SHOW TO USER. List available backup files in .c5t/ directory."
      input_schema: {
        type: "object"
        properties: {}
      }
    }
    {
      name: "list_items"
      description: "SHOW TO USER. View all todos with status, priority, and timestamps. Filter by status if needed."
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
      description: "SHOW TO USER. See what's left to do (excludes completed/cancelled)."
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
      description: "Add progress notes or decisions to a list (markdown supported)"
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
      description: "Save important info or decisions as a searchable note (markdown supported). Tip: Use tag 'session' for notes that track context across conversation compactions."
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
      description: "SHOW TO USER. Browse all saved notes and archived work. Filter by tags or type. Lost context? Look for notes tagged 'session'."
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
            description: "Filter by note type: 'manual' (user-created notes), 'archived_todo' (completed todo lists) (optional)"
            enum: ["manual" "archived_todo"]
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
      description: "SHOW TO USER. Retrieve a saved note or archived list."
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "integer"
            description: "ID of the note to retrieve (from list_notes or search results)"
          }
        }
        required: ["note_id"]
      }
    }
    {
      name: "search"
      description: "SHOW TO USER. Find past work instantly. Searches all notes and archived todos with boolean operators (AND, OR, NOT)."
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
      name: "get_summary"
      description: "SHOW TO USER. Quick status overview: active lists, in-progress items, priorities. Perfect for session start. For detailed context, check notes tagged 'session'."
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

    "delete_item" => {
      let validation = validate-item-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      let list_id = $parsed_args.list_id
      let item_id = $parsed_args.item_id

      let result = delete-item $list_id $item_id

      if not $result.success {
        return $result.error
      }

      $"✓ Item deleted \(ID: ($item_id)\)"
    }

    "edit_item" => {
      let validation = validate-item-update-input $parsed_args
      if not $validation.valid {
        return $validation.error
      }

      if "content" not-in $parsed_args {
        return "Error: Missing required field: 'content'"
      }

      let list_id = $parsed_args.list_id
      let item_id = $parsed_args.item_id
      let content = $parsed_args.content

      let result = edit-item $list_id $item_id $content

      if not $result.success {
        return $result.error
      }

      $"✓ Item updated \(ID: ($item_id)\)
  New content: ($content)"
    }

    "delete_list" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id
      let force = if "force" in $parsed_args { $parsed_args.force } else { false }

      let result = delete-list $list_id $force

      if not $result.success {
        return $result.error
      }

      if $force {
        $"✓ List and all items deleted \(ID: ($list_id)\)"
      } else {
        $"✓ List deleted \(ID: ($list_id)\)"
      }
    }

    "delete_note" => {
      if "note_id" not-in $parsed_args {
        return "Error: Missing required field: 'note_id'"
      }

      let note_id = $parsed_args.note_id

      let result = delete-note $note_id

      if not $result.success {
        return $result.error
      }

      $"✓ Note deleted \(ID: ($note_id)\)"
    }

    "rename_list" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      if "name" not-in $parsed_args {
        return "Error: Missing required field: 'name'"
      }

      let list_id = $parsed_args.list_id
      let name = $parsed_args.name
      let description = if "description" in $parsed_args { $parsed_args.description } else { null }

      let result = rename-list $list_id $name $description

      if not $result.success {
        return $result.error
      }

      if $description != null {
        $"✓ List renamed \(ID: ($list_id)\)
  New name: ($name)
  New description: ($description)"
      } else {
        $"✓ List renamed \(ID: ($list_id)\)
  New name: ($name)"
      }
    }

    "bulk_add_items" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      if "items" not-in $parsed_args {
        return "Error: Missing required field: 'items'"
      }

      let list_id = $parsed_args.list_id
      let items = $parsed_args.items

      let result = bulk-add-items $list_id $items

      if not $result.success {
        return $result.error
      }

      let ids_str = $result.ids | str join ", "
      $"✓ Added ($result.count) items to list ($list_id)
  IDs: ($ids_str)"
    }

    "move_item" => {
      if "source_list_id" not-in $parsed_args {
        return "Error: Missing required field: 'source_list_id'"
      }

      if "item_id" not-in $parsed_args {
        return "Error: Missing required field: 'item_id'"
      }

      if "target_list_id" not-in $parsed_args {
        return "Error: Missing required field: 'target_list_id'"
      }

      let source_list_id = $parsed_args.source_list_id
      let item_id = $parsed_args.item_id
      let target_list_id = $parsed_args.target_list_id

      let result = move-item $source_list_id $item_id $target_list_id

      if not $result.success {
        return $result.error
      }

      $"✓ Item moved \(ID: ($item_id)\)
  From list: ($source_list_id)
  To list: ($target_list_id)"
    }

    "bulk_update_status" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      if "item_ids" not-in $parsed_args {
        return "Error: Missing required field: 'item_ids'"
      }

      if "status" not-in $parsed_args {
        return "Error: Missing required field: 'status'"
      }

      let list_id = $parsed_args.list_id
      let item_ids = $parsed_args.item_ids
      let status = $parsed_args.status

      let result = bulk-update-status $list_id $item_ids $status

      if not $result.success {
        return $result.error
      }

      if $result.archived {
        $"✓ Updated ($result.count) items to '($status)'
  List auto-archived \(Note ID: ($result.note_id)\)"
      } else {
        $"✓ Updated ($result.count) items to '($status)'"
      }
    }

    "get_list" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id

      let result = get-list $list_id

      if not $result.success {
        return $result.error
      }

      format-list-detail $result.list
    }

    "archive_list" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id

      let result = archive-list-manual $list_id

      if not $result.success {
        return $result.error
      }

      $"✓ List archived \(ID: ($list_id)\)
  Archive note created \(Note ID: ($result.note_id)\)"
    }

    "export_data" => {
      let result = export-data

      if not $result.success {
        return $result.error
      }

      # Generate filename
      let timestamp = date now | format date "%Y%m%d-%H%M%S"
      let filename = if "filename" in $parsed_args and $parsed_args.filename != null {
        $parsed_args.filename
      } else {
        $"backup-($timestamp).json"
      }

      # Ensure .c5t directory exists
      let backup_dir = ".c5t"
      if not ($backup_dir | path exists) {
        mkdir $backup_dir
      }

      # Write backup file
      let filepath = $"($backup_dir)/($filename)"
      $result.data | to json --indent 2 | save -f $filepath

      $"✓ Backup saved to ($filepath)
  Lists: ($result.data.lists | length)
  Items: ($result.data.items | length)
  Notes: ($result.data.notes | length)"
    }

    "import_data" => {
      if "filename" not-in $parsed_args {
        return "Error: Missing required field: 'filename'"
      }

      let filename = $parsed_args.filename
      let merge = if "merge" in $parsed_args { $parsed_args.merge } else { false }

      # Build filepath
      let filepath = $".c5t/($filename)"

      # Check if file exists
      if not ($filepath | path exists) {
        return $"Error: Backup file not found: ($filepath)

Use list_backups to see available backup files."
      }

      # Read and parse the backup file
      let data = try {
        open $filepath
      } catch {
        return $"Error: Failed to read backup file: ($filepath)"
      }

      let result = if $merge {
        import-data $data --merge
      } else {
        import-data $data
      }

      if not $result.success {
        return $result.error
      }

      $"✓ Data imported from ($filepath)
  Lists: ($result.imported.lists)
  Items: ($result.imported.items)
  Notes: ($result.imported.notes)"
    }

    "list_backups" => {
      let backup_dir = ".c5t"

      if not ($backup_dir | path exists) {
        return "No backup directory found. Run export_data first to create a backup."
      }

      let backups = glob $"($backup_dir)/*.json" | sort -r

      if ($backups | is-empty) {
        return "No backup files found in .c5t/"
      }

      let backup_info = $backups | each {|file|
          let stat = ls $file | first
          {
            filename: ($file | path basename)
            size: $stat.size
            modified: $stat.modified
          }
        }

      let lines = ["Available backups:" ""]
      let file_lines = $backup_info | each {|b|
          $"  ($b.filename) \(($b.size), ($b.modified)\)"
        }

      [...$lines ...$file_lines "" "Use import_data with filename to restore."] | str join (char newline)
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

      format-items-table $result.list $result.items
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

      format-items-table $result.list $result.items
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
