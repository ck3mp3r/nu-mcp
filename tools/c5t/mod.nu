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

    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
