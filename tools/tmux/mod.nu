# Tmux management tool for nu-mcp - provides tmux session and pane control
# Uses modular structure with helper modules for better organization

# Import helper modules
use core.nu *
use session.nu *
use commands.nu *
use process.nu *
use search.nu *

# Default main command
def main [] {
  help main
}

# List available MCP tools
def "main list-tools" [] {
  [
    {
      name: "list_sessions"
      description: "List all tmux sessions with their windows and panes (returns tabular data)"
      input_schema: {
        type: "object"
        properties: {}
        additionalProperties: false
      }
    }
    {
      name: "send_and_capture"
      description: "DEFAULT: Send a command to a tmux pane and capture its output. This is the standard way to interact with tmux panes."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, defaults to current window)"
          }
          pane: {
            type: "string"
            description: "Pane ID (optional, defaults to current pane)"
          }
          command: {
            type: "string"
            description: "Command to send and capture output from (e.g. 'ls -la', 'git status', 'npm test', 'cargo build')"
          }
          wait_seconds: {
            type: "number"
            description: "Seconds to wait before capturing output (optional, defaults to 1)"
          }
          lines: {
            type: "integer"
            description: "Number of lines to capture (optional, defaults to all visible)"
          }
        }
        required: ["session" "command"]
      }
    }
    {
      name: "send_command"
      description: "Send command to tmux pane without capturing output (fire-and-forget). Use only when you don't need output or for long-running processes."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, defaults to current window)"
          }
          pane: {
            type: "string"
            description: "Pane ID (optional, defaults to current pane)"
          }
          command: {
            type: "string"
            description: "Command to send to the pane (for fire-and-forget only - use send_and_capture if you need output)"
          }
        }
        required: ["session" "command"]
      }
    }
    {
      name: "capture_pane"
      description: "Capture current visible content of a tmux pane. For running commands and getting output, use send_and_capture instead."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, defaults to current window)"
          }
          pane: {
            type: "string"
            description: "Pane ID (optional, defaults to current pane)"
          }
          lines: {
            type: "integer"
            description: "Number of lines to capture (optional, defaults to all visible)"
          }
        }
        required: ["session"]
      }
    }
    {
      name: "get_session_info"
      description: "Get detailed information about a specific tmux session."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
        }
        required: ["session"]
      }
    }
    {
      name: "get_pane_process"
      description: "Get information about the running process in a tmux pane."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, defaults to current window)"
          }
          pane: {
            type: "string"
            description: "Pane ID (optional, defaults to current pane)"
          }
        }
        required: ["session"]
      }
    }
    {
      name: "find_pane_by_name"
      description: "Find a pane by its name across windows in a session."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          pane_name: {
            type: "string"
            description: "Name of the pane to find"
          }
        }
        required: ["session" "pane_name"]
      }
    }
    {
      name: "find_pane_by_context"
      description: "Find a pane by context like directory path or command."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          context: {
            type: "string"
            description: "Context to search for: directory name (e.g. 'docs'), command (e.g. 'zola'), or description"
          }
        }
        required: ["session" "context"]
      }
    }
    {
      name: "list_panes"
      description: "List all panes in a session with their details."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
        }
        required: ["session"]
      }
    }
  ] | to json
}

# Call a specific tool with arguments
def "main call-tool" [
  tool_name: string # Name of the tool to call
  args: any = {} # JSON arguments for the tool
] {
  let parsed_args = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  match $tool_name {
    "list_sessions" => {
      list_sessions
    }
    "send_command" => {
      let session = $parsed_args | get session
      let command = $parsed_args | get command
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      let pane = if "pane" in $parsed_args { $parsed_args | get pane } else { null }
      send_command $session $command $window $pane
    }
    "capture_pane" => {
      let session = $parsed_args | get session
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      let pane = if "pane" in $parsed_args { $parsed_args | get pane } else { null }
      let lines = if "lines" in $parsed_args { $parsed_args | get lines } else { null }
      capture_pane $session $window $pane $lines
    }
    "get_session_info" => {
      let session = $parsed_args | get session
      get_session_info $session
    }
    "get_pane_process" => {
      let session = $parsed_args | get session
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      let pane = if "pane" in $parsed_args { $parsed_args | get pane } else { null }
      get_pane_process $session $window $pane
    }
    "find_pane_by_name" => {
      let session = $parsed_args | get session
      let pane_name = $parsed_args | get pane_name
      find_pane_by_name $session $pane_name
    }
    "find_pane_by_context" => {
      let session = $parsed_args | get session
      let context = $parsed_args | get context
      find_pane_by_context $session $context
    }
    "list_panes" => {
      let session = $parsed_args | get session
      list_panes $session
    }
    "send_and_capture" => {
      let session = $parsed_args | get session
      let command = $parsed_args | get command
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      let pane = if "pane" in $parsed_args { $parsed_args | get pane } else { null }
      let wait_seconds = if "wait_seconds" in $parsed_args { $parsed_args | get wait_seconds } else { 1 }
      let lines = if "lines" in $parsed_args { $parsed_args | get lines } else { null }
      send_and_capture $session $command $window $pane $wait_seconds $lines
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
