# Configuration Guide

The `nu-mcp` server is configured via command-line arguments or by passing arguments as part of a process launch configuration.

## Command Line Options

### Extension System Options
- `--tools-dir=PATH`
  Directory containing tool modules. When specified, the server automatically discovers and loads all directories containing `mod.nu` files as MCP tools. **Important**: Using this flag automatically disables the `run_nushell` tool by default to prevent conflicts between multiple MCP server instances and avoid confusion when the same server provides both generic command execution and specific tools.
- `--enable-run-nushell`
  Explicitly re-enable the `run_nushell` tool when using `--tools-dir`. This creates a hybrid mode where both extension tools and generic nushell command execution are available. Use with caution in multi-instance setups to avoid tool name conflicts.

### Security Options
- `--sandbox-dir=PATH`
  Directory to sandbox nushell execution (default: current working directory). Commands are restricted to this directory and cannot access parent directories or absolute paths outside the sandbox.

## Example Configurations

### Basic Core Mode
```yaml
nu-mcp-core:
  command: "nu-mcp"
  args:
    - "--sandbox-dir=/safe/workspace"
```

### Extension Mode Only
```yaml
nu-mcp-tools:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--sandbox-dir=/safe/workspace"
```

### Hybrid Mode
```yaml
nu-mcp-hybrid:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--enable-run-nushell"
    - "--sandbox-dir=/safe/workspace"
```