# GitHub tool utility functions
# gh CLI wrapper, safety modes, and helper functions

# Safety mode configuration
# MCP_GITHUB_MODE: "readonly" or "readwrite" (default)
#
# All current tools are non-destructive:
# - readonly: list, get, view operations
# - write: create/update PRs, trigger workflows (not destructive - doesn't delete anything)
#
# Future destructive tools (delete_pr, delete_branch, etc.) would need a "destructive" mode

# Get current safety mode
export def get-safety-mode [] {
  $env.MCP_GITHUB_MODE? | default "readwrite"
}

# List of readonly tools
export def readonly-tools [] {
  [
    "list_workflows"
    "list_workflow_runs"
    "get_workflow_run"
    "list_prs"
    "get_pr"
    "get_pr_checks"
  ]
}

# List of write tools (create/update - not destructive)
export def write-tools [] {
  [
    "run_workflow"
    "upsert_pr"
  ]
}

# Check if a tool is allowed in the current safety mode
export def is-tool-allowed [tool_name: string] {
  let mode = get-safety-mode
  match $mode {
    "readonly" => { $tool_name in (readonly-tools) }
    "readwrite" => { true } # All current tools are allowed
    _ => { true } # Default to readwrite for unknown modes
  }
}

# Check tool permission and return error message if not allowed
export def check-tool-permission [tool_name: string] {
  if not (is-tool-allowed $tool_name) {
    let mode = get-safety-mode
    error make {
      msg: $"Tool '($tool_name)' requires readwrite mode. Current mode: ($mode). Set MCP_GITHUB_MODE=readwrite to enable."
    }
  }
}

# Run gh command with optional path (working directory)
# Returns the output string or error
export def run-gh [
  args: list<string>
  --path: string = ""
] {
  let result = if $path != "" {
    cd $path
    try {
      gh ...$args
    } catch {|err|
      error make {msg: $"gh command failed: ($err.msg)"}
    }
  } else {
    try {
      gh ...$args
    } catch {|err|
      error make {msg: $"gh command failed: ($err.msg)"}
    }
  }

  $result
}

# Run gh command and parse JSON output
export def run-gh-json [
  args: list<string>
  --path: string = ""
] {
  let result = run-gh $args --path $path
  $result | from json
}

# Extract path from args record, defaulting to current directory
export def get-path [args: record] {
  if "path" in $args and $args.path != null {
    $args.path
  } else {
    ""
  }
}

# Get optional parameter from args with default
export def get-optional [args: record key: string default: any] {
  if $key in $args and ($args | get $key) != null {
    $args | get $key
  } else {
    $default
  }
}
