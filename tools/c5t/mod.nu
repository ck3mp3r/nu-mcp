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
      name: "upsert_list"
      description: "Create or update a todo list. Omit list_id to create new, provide list_id to update. Supports name, description, tags, and progress notes."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of list to update (omit to create new)"
          }
          name: {
            type: "string"
            description: "Name of the todo list (required for new lists)"
          }
          description: {
            type: "string"
            description: "Brief description of what this list is for (optional)"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Tags to organize the list (optional)"
          }
          notes: {
            type: "string"
            description: "Progress notes, decisions, or context for this list (markdown supported)"
          }
        }
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
      name: "upsert_item"
      description: "Create or update a todo item. Omit item_id to create new, provide item_id to update. Can set content, priority, status in one call. Auto-timestamps on status changes."
      input_schema: {
        type: "object"
        properties: {
          list_id: {
            type: "integer"
            description: "ID of the todo list"
          }
          item_id: {
            type: "integer"
            description: "ID of item to update (omit to create new)"
          }
          content: {
            type: "string"
            description: "Description of the todo item (required for new items)"
          }
          priority: {
            type: "integer"
            description: "Priority level (1-5, where 1 is highest priority) (optional)"
            minimum: 1
            maximum: 5
          }
          status: {
            type: "string"
            description: "Status (defaults to 'backlog' for new items)"
            enum: ["backlog" "todo" "in_progress" "review" "done" "cancelled"]
          }
        }
        required: ["list_id"]
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
      description: "Import c5t data from JSON backup file. Replaces all existing data. Use list_backups to see available files."
      input_schema: {
        type: "object"
        properties: {
          filename: {
            type: "string"
            description: "Backup filename in .c5t/ directory (e.g., 'backup-20251215-120000.json')"
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
      name: "upsert_note"
      description: "Create or update a note. Provide note_id to update existing, omit to create new. Tip: Use tag 'session' for context across compactions."
      input_schema: {
        type: "object"
        properties: {
          note_id: {
            type: "integer"
            description: "ID of note to update (omit to create new)"
          }
          title: {
            type: "string"
            description: "Title of the note (required for new notes)"
          }
          content: {
            type: "string"
            description: "Markdown-formatted content (required for new notes)"
          }
          tags: {
            type: "array"
            items: {type: "string"}
            description: "Tags to organize the note (optional)"
          }
        }
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
    "upsert_list" => {
      let list_id = if "list_id" in $parsed_args { $parsed_args.list_id } else { null }
      let name = if "name" in $parsed_args { $parsed_args.name } else { null }
      let description = if "description" in $parsed_args { $parsed_args.description } else { null }
      let tags = if "tags" in $parsed_args { $parsed_args.tags } else { null }
      let notes = if "notes" in $parsed_args { $parsed_args.notes } else { null }

      let result = upsert-list $list_id $name $description $tags $notes

      if not $result.success {
        return $result.error
      }

      if $result.created {
        format-list-created $result
      } else {
        $"✓ List updated
  ID: ($result.list.id)
  Name: ($result.list.name)"
      }
    }

    "list_active" => {
      let tag_filter = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = get-active-lists $tag_filter

      if not $result.success {
        return $result.error
      }

      format-active-lists $result.lists
    }

    "upsert_item" => {
      if "list_id" not-in $parsed_args {
        return "Error: Missing required field: 'list_id'"
      }

      let list_id = $parsed_args.list_id
      let item_id = if "item_id" in $parsed_args { $parsed_args.item_id } else { null }
      let content = if "content" in $parsed_args { $parsed_args.content } else { null }
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

      let result = upsert-item $list_id $item_id $content $priority $status

      if not $result.success {
        return $result.error
      }

      if $result.created {
        format-item-created $result
      } else if $result.archived {
        format-item-updated-with-archive "item" $result.item.id "updated" $result.note_id
      } else {
        $"✓ Item updated
  ID: ($result.item.id)
  Content: ($result.item.content)"
      }
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

      let result = import-data $data

      if not $result.success {
        return $result.error
      }

      $"✓ Data restored from ($filepath)
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

    "upsert_note" => {
      let note_id = if "note_id" in $parsed_args { $parsed_args.note_id } else { null }
      let title = if "title" in $parsed_args { $parsed_args.title } else { null }
      let content = if "content" in $parsed_args { $parsed_args.content } else { null }
      let tags = if "tags" in $parsed_args { $parsed_args.tags } else { null }

      let result = upsert-note $note_id $title $content $tags

      if not $result.success {
        return $result.error
      }

      if $result.created {
        format-note-created-manual $result
      } else {
        $"✓ Note updated
  ID: ($result.note.id)
  Title: ($result.note.title)"
      }
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

      let result = get-note $note_id

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
