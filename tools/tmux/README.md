# Tmux MCP Tool

Comprehensive tmux session management and control tool for the `nu-mcp` server. Provides intelligent command execution, pane discovery, and session monitoring capabilities designed for AI assistant integration.

### Available Tools

**Session & Information:**
- `list_sessions` - List all tmux sessions with windows and panes
- `get_session_info` - Get detailed session information
- `list_panes` - List all panes in a session
- `create_session` - Create new tmux sessions with ownership tracking

**Command Execution:**
- `send_and_capture` - **PREFERRED**: Send commands and capture output (interactive)
- `send_command` - Send commands without waiting for output (fire-and-forget)
- `capture_pane` - Capture current visible content (static snapshot)

**Pane Discovery:**
- `find_pane_by_name` - Find panes by exact name
- `find_pane_by_context` - Find panes by context (directory, command, description)
- `get_pane_process` - Get process information for panes

**Window & Pane Management:**
- `create_window` - Create new windows in a session
- `split_pane` - Split panes horizontally or vertically
- `select_layout` - Arrange panes with predefined layouts

**Destructive Operations (Safety Protected):**
- `kill_pane` - **DESTRUCTIVE**: Close MCP-created panes
- `kill_window` - **DESTRUCTIVE**: Close MCP-created windows
- `kill_session` - **DESTRUCTIVE**: Close MCP-created sessions

### Key Features

- **Intelligent command execution**: `send_and_capture` with exponential back-off polling
- **LLM-optimized tool selection**: Clear naming patterns guide AI assistants to the right tool
- **Context-aware pane finding**: Find panes by name, directory, or process (e.g., "docs", "build")
- **Structured table output**: All results formatted for easy reading
- **Command logging**: Full execution tracing for debugging

### Tool Selection Guide

**For interactive commands that need output** (builds, tests, git status):
```
send_and_capture - Automatically handles timing and captures results
```

**For fire-and-forget commands** (starting processes, background tasks):
```
send_command - Returns immediately without waiting
```

**For viewing current pane content** (checking status, reading logs):
```
capture_pane - Static snapshot of what's currently displayed
```

## Installation

### Individual Tool
```bash
nix profile install github:ck3mp3r/nu-mcp#tmux-mcp-tools
```

### All Tools
```bash
nix profile install github:ck3mp3r/nu-mcp#mcp-tools
```

Installs to `~/.nix-profile/share/nushell/mcp-tools/tmux/`

### Manual
Copy the entire `tmux/` directory (including `mod.nu` and helper modules) to your nu-mcp tools directory.

## Modular Structure

The tool is organized into focused modules for maintainability:

- **`mod.nu`** - MCP interface and tool orchestration
- **`core.nu`** - Basic tmux utilities and command execution
- **`session.nu`** - Session listing and detailed information
- **`commands.nu`** - Command execution with intelligent output capture
- **`process.nu`** - Process information and management
- **`search.nu`** - Pane discovery by name and context
- **`workload.nu`** - Window and pane creation/management

## Usage

### MCP Server Configuration
```yaml
nu-mcp-tmux:
  command: "nu-mcp"
  args:
    - "--tools-dir"
    - "~/.nix-profile/share/nushell/mcp-tools/tmux"
```

### Example Operations

**Session Management:**
- Discover all tmux sessions with their window/pane structure
- Get detailed session information with nested pane tables
- Monitor session status and attachment state

**Command Execution:**
- **Interactive commands**: `send_and_capture` with smart polling for builds, tests, git operations
- **Background tasks**: `send_command` for fire-and-forget process starting
- **Content viewing**: `capture_pane` for reading logs or current terminal state

**Intelligent Pane Discovery:**
- Find panes by exact name match
- Search by context (directory name, running command, process type)
- Locate development environments ("docs", "build", "test", etc.)

**Process Monitoring:**
- Get detailed process information including PIDs and command lines
- Monitor pane status and activity
- Track resource usage and pane dimensions

**Window & Pane Management:**
- Create new windows with optional name and working directory
- Split panes horizontally (side-by-side) or vertically (top-bottom)
- Specify working directory for new windows/panes
- Automated workspace setup for development environments
- Arrange panes with predefined layouts (tiled, main-horizontal, etc.)

**Safe Resource Cleanup:**
- Close panes, windows, or sessions created by MCP
- Safety checks prevent accidental destruction of user-created resources
- All destructive operations require explicit `force=true` confirmation
- Ownership tracking via `@mcp_tmux` markers (invisible to users)

## Session, Window & Pane Management Details

### create_session
Create a new tmux session with MCP ownership tracking. The session is automatically marked with `@mcp_tmux`, enabling safe destruction later with `kill_session`.

**Parameters:**
- `name` (required) - Unique name for the new session
- `window_name` (optional) - Name for the initial window
- `directory` (optional) - Starting directory for the session (defaults to current directory)
- `detached` (optional) - Create in detached mode (default: `true` - doesn't switch focus)

**Example:**
```json
{
  "name": "my-workspace",
  "window_name": "editor",
  "directory": "/home/user/project",
  "detached": true
}
```

**Returns:** JSON with session ID, session name, and creation status

**Notes:**
- By default creates detached sessions to avoid disrupting user's current work
- Session is marked with `@mcp_tmux` ownership marker
- Can be safely destroyed later using `kill_session` (with `force: true`)
- Duplicate session names are rejected with clear error message

### create_window
Create a new window in an existing tmux session.

**Parameters:**
- `session` (required) - Session name or ID
- `name` (optional) - Name for the new window
- `directory` (optional) - Working directory for the new window
- `target` (optional) - Target window index

**Example:**
```json
{
  "session": "dev",
  "name": "frontend",
  "directory": "/home/user/project/frontend"
}
```

**Returns:** JSON with window ID, index, and success message

### split_pane
Split a pane in a tmux window horizontally or vertically.

**Parameters:**
- `session` (required) - Session name or ID
- `direction` (required) - "horizontal" (left/right) or "vertical" (top/bottom)
- `window` (optional) - Window name or ID (defaults to current)
- `pane` (optional) - Pane ID to split (defaults to current)
- `directory` (optional) - Working directory for the new pane
- `size` (optional) - Size of new pane as percentage (default: 50)

**Example:**
```json
{
  "session": "dev",
  "direction": "horizontal",
  "directory": "/home/user/project/backend"
}
```

**Returns:** JSON with pane ID, direction, and success message

### select_layout
Arrange panes in a window using predefined layouts. Non-destructive operation.

**Parameters:**
- `session` (required) - Session name or ID
- `layout` (required) - Layout name (see below)
- `window` (optional) - Window name or ID (defaults to current)

**Available Layouts:**
- `even-horizontal` - Equal width columns
- `even-vertical` - Equal height rows
- `main-horizontal` - Large top pane with smaller panes below
- `main-vertical` - Large left pane with smaller panes on the right
- `tiled` - Grid arrangement

**Example:**
```json
{
  "session": "dev",
  "layout": "main-vertical",
  "window": "frontend"
}
```

**Returns:** JSON with layout name and success message

## Destructive Operations (Phase 3)

### Safety Model

All destructive operations (`kill_pane`, `kill_window`, `kill_session`) implement dual safety checks:

1. **Force Flag Required**: Must explicitly set `force: true` in parameters
2. **Ownership Verification**: Can ONLY destroy resources created by MCP (marked with `@mcp_tmux`)

This ensures LLMs can clean up their own work without accidentally destroying user-created tmux resources.

### kill_pane
Close a tmux pane. **DESTRUCTIVE OPERATION**.

**Safety Checks:**
- Requires `force: true` parameter
- Only works on panes created via `split_pane` (have `@mcp_tmux` marker)
- Returns error if pane was user-created

**Parameters:**
- `session` (required) - Session name or ID
- `pane` (required) - Pane ID (e.g., '%4')
- `window` (optional) - Window name or ID for targeting
- `force` (required) - Must be `true` to confirm

**Example:**
```json
{
  "session": "dev",
  "pane": "%4",
  "force": true
}
```

**Returns:** Success message or ownership/force error

### kill_window
Close a tmux window and all its panes. **DESTRUCTIVE OPERATION**.

**Safety Checks:**
- Requires `force: true` parameter
- Only works on windows created via `create_window` (have `@mcp_tmux` marker)
- Returns error if window was user-created

**Parameters:**
- `session` (required) - Session name or ID
- `window` (required) - Window name or ID (e.g., '@2' or 'frontend')
- `force` (required) - Must be `true` to confirm

**Example:**
```json
{
  "session": "dev",
  "window": "frontend",
  "force": true
}
```

**Returns:** Success message or ownership/force error

### kill_session
Destroy a tmux session and all its windows/panes. **DESTRUCTIVE OPERATION**.

**Safety Checks:**
- Requires `force: true` parameter
- Only works on sessions created by MCP (have `@mcp_tmux` marker)
- Returns error if session was user-created

**Parameters:**
- `session` (required) - Session name or ID to destroy
- `force` (required) - Must be `true` to confirm

**Example:**
```json
{
  "session": "mcp-test-session",
  "force": true
}
```

**Returns:** Success message or ownership/force error

### Ownership Tracking

When MCP creates windows or panes via `create_window` or `split_pane`, they are automatically marked with a `@mcp_tmux` user option. This marker:
- Is invisible in the tmux UI
- Persists until the resource is destroyed
- Enables ownership verification for destructive operations
- Prevents accidental destruction of user work

**Note:** Future versions may add `create_session` which will also mark sessions for safe cleanup.

## Requirements

- **tmux**: Installed and available in PATH
- **nu-mcp server**: Version 0.3.1 or later
- **Nushell**: For module execution and command processing

## Integration Notes

This tool is optimized for AI assistant integration with:
- **Structured output**: All results in clean table formats for easy parsing
- **Context-aware discovery**: Smart pane finding reduces need for manual target specification  
- **Intelligent polling**: Automatic output detection minimizes wait times
- **Comprehensive logging**: Full command traceability for debugging and verification
