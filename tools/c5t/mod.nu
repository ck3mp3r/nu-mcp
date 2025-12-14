# c5t (Context) Tool for nu-mcp - Context/memory management across sessions

# Import helper modules
use storage.nu *
use formatters.nu *
use utils.nu *

def main [] {
  help main
}

# List all available tools
def "main list-tools" [] {
  # Initialize database on first access
  init-database | ignore

  [
    # Tools will be added in later milestones
  ] | to json
}

# Execute a tool by name with arguments
def "main call-tool" [
  tool_name: string
  args: any = {}
] {
  # Parse arguments - handle both string (from Rust) and record (from direct calls)
  let parsed_args = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  # Route to appropriate tool implementation
  match $tool_name {
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
