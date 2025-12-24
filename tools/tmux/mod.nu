# Tmux management tool for nu-mcp - provides tmux session and pane control
# Uses modular structure with helper modules for better organization

# Import helper modules
use core.nu *
use session.nu *
use commands.nu *
use process.nu *
use search.nu *
use workload.nu *

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
    {
      name: "create_session"
      description: "Create a new tmux session with ownership tracking. The session will be marked as MCP-created, allowing safe destruction later with kill_session. By default, creates a detached session (does not switch focus)."
      input_schema: {
        type: "object"
        properties: {
          name: {
            type: "string"
            description: "Name for the new session (required). Must be unique across all tmux sessions."
          }
          window_name: {
            type: "string"
            description: "Name for the initial window (optional, defaults to tmux default)"
          }
          directory: {
            type: "string"
            description: "Starting directory for the session (optional, defaults to current directory)"
          }
          detached: {
            type: "boolean"
            description: "Create session in detached mode (optional, default: true). If false, switches to the new session."
          }
        }
        required: ["name"]
      }
    }
    {
      name: "create_window"
      description: "Create a new window in a tmux session. Optionally specify window name, working directory, and target index."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          name: {
            type: "string"
            description: "Name for the new window (optional)"
          }
          directory: {
            type: "string"
            description: "Working directory for the new window (optional, defaults to session's default)"
          }
          target: {
            type: "integer"
            description: "Target window index (optional, defaults to next available)"
          }
        }
        required: ["session"]
      }
    }
    {
      name: "split_pane"
      description: "Split a pane in a tmux window horizontally or vertically. Optionally specify working directory and size."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          direction: {
            type: "string"
            enum: ["horizontal" "vertical"]
            description: "Split direction: 'horizontal' creates left/right panes, 'vertical' creates top/bottom panes"
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, defaults to current window)"
          }
          pane: {
            type: "string"
            description: "Pane ID to split (optional, defaults to current pane)"
          }
          directory: {
            type: "string"
            description: "Working directory for the new pane (optional)"
          }
          size: {
            type: "integer"
            description: "Size of new pane as percentage (optional, defaults to 50)"
          }
        }
        required: ["session" "direction"]
      }
    }
    {
      name: "kill_pane"
      description: "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING. Permanently closes a tmux pane. Can ONLY destroy panes created by MCP (marked with @mcp_tmux). Requires explicit force flag."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          pane: {
            type: "string"
            description: "Pane ID to kill (e.g., '%4'). REQUIRED."
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, for targeting pane in specific window)"
          }
          force: {
            type: "boolean"
            description: "REQUIRED: Must be true to confirm destruction. This operation cannot be undone."
          }
        }
        required: ["session" "pane" "force"]
      }
    }
    {
      name: "kill_window"
      description: "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING. Permanently closes a tmux window and all its panes. Can ONLY destroy windows created by MCP (marked with @mcp_tmux). Requires explicit force flag."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          window: {
            type: "string"
            description: "Window name or ID to kill (e.g., '@2' or 'frontend'). REQUIRED."
          }
          force: {
            type: "boolean"
            description: "REQUIRED: Must be true to confirm destruction. This operation cannot be undone."
          }
        }
        required: ["session" "window" "force"]
      }
    }
    {
      name: "kill_session"
      description: "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING. Permanently destroys a tmux session and all its windows and panes. Can ONLY destroy sessions created by MCP (marked with @mcp_tmux). Requires explicit force flag."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID to kill. REQUIRED."
          }
          force: {
            type: "boolean"
            description: "REQUIRED: Must be true to confirm destruction. This operation cannot be undone."
          }
        }
        required: ["session" "force"]
      }
    }
    {
      name: "select_layout"
      description: "Select a layout for arranging panes in a tmux window. Non-destructive operation that only changes visual arrangement."
      input_schema: {
        type: "object"
        properties: {
          session: {
            type: "string"
            description: "Session name or ID"
          }
          layout: {
            type: "string"
            enum: ["even-horizontal" "even-vertical" "main-horizontal" "main-vertical" "tiled"]
            description: "Layout name: 'even-horizontal' (equal width columns), 'even-vertical' (equal height rows), 'main-horizontal' (large top pane), 'main-vertical' (large left pane), 'tiled' (grid)"
          }
          window: {
            type: "string"
            description: "Window name or ID (optional, defaults to current window)"
          }
        }
        required: ["session" "layout"]
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
    "create_session" => {
      let name = $parsed_args | get name
      let window_name = if "window_name" in $parsed_args { $parsed_args | get window_name } else { null }
      let directory = if "directory" in $parsed_args { $parsed_args | get directory } else { null }
      let detached = if "detached" in $parsed_args { $parsed_args | get detached } else { true }
      create-session $name --window-name $window_name --directory $directory --detached $detached
    }
    "create_window" => {
      let session = $parsed_args | get session
      let name = if "name" in $parsed_args { $parsed_args | get name } else { null }
      let directory = if "directory" in $parsed_args { $parsed_args | get directory } else { null }
      let target = if "target" in $parsed_args { $parsed_args | get target } else { null }
      create_window $session --name $name --directory $directory --target $target
    }
    "split_pane" => {
      let session = $parsed_args | get session
      let direction = $parsed_args | get direction
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      let pane = if "pane" in $parsed_args { $parsed_args | get pane } else { null }
      let directory = if "directory" in $parsed_args { $parsed_args | get directory } else { null }
      let size = if "size" in $parsed_args { $parsed_args | get size } else { null }
      split_pane $session $direction --window $window --pane $pane --directory $directory --size $size
    }
    "kill_pane" => {
      let session = $parsed_args | get session
      let pane = $parsed_args | get pane
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      let force = if "force" in $parsed_args { $parsed_args | get force } else { false }
      if $force {
        kill_pane $session --pane $pane --window $window --force
      } else {
        kill_pane $session --pane $pane --window $window
      }
    }
    "kill_window" => {
      let session = $parsed_args | get session
      let window = $parsed_args | get window
      let force = if "force" in $parsed_args { $parsed_args | get force } else { false }
      if $force {
        kill_window $session --window $window --force
      } else {
        kill_window $session --window $window
      }
    }
    "kill_session" => {
      let session = $parsed_args | get session
      let force = if "force" in $parsed_args { $parsed_args | get force } else { false }
      if $force {
        kill_session $session --force
      } else {
        kill_session $session
      }
    }
    "select_layout" => {
      let session = $parsed_args | get session
      let layout = $parsed_args | get layout
      let window = if "window" in $parsed_args { $parsed_args | get window } else { null }
      select_layout $session $layout --window $window
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
