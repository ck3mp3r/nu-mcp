# Tmux MCP Tool

Comprehensive tmux session management and control tool for the `nu-mcp` server. Provides intelligent command execution, pane discovery, and session monitoring capabilities designed for AI assistant integration.

### Available Tools

- `list_sessions` - List all tmux sessions with windows and panes
- `send_and_capture` - **PREFERRED**: Send commands and capture output (interactive)
- `send_command` - Send commands without waiting for output (fire-and-forget)
- `capture_pane` - Capture current visible content (static snapshot)
- `get_session_info` - Get detailed session information
- `get_pane_process` - Get process information for panes
- `find_pane_by_name` - Find panes by exact name
- `find_pane_by_context` - Find panes by context (directory, command, description)
- `list_panes` - List all panes in a session

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
nix profile install github:ck3mp3r/nu-mcp#mcp-tmux-tool
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
