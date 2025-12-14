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
            type: "string"
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
            type: "string"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "string"
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
            type: "string"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "string"
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
            type: "string"
            description: "ID of the todo list containing the item"
          }
          item_id: {
            type: "string"
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
            type: "string"
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
            type: "string"
            description: "ID of the todo list"
          }
        }
        required: ["list_id"]
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

      format-item-updated "status" $item_id $status
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

      format-item-completed $item_id
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

    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
