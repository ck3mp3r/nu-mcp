# Configuration Guide

The `nu-mcp` server is configured via command-line arguments or by passing arguments as part of a process launch configuration.

## Command Line Options

### Extension System Options
- `--tools-dir=PATH`
  Directory containing tool modules. When specified, the server automatically discovers and loads all directories containing `mod.nu` files as MCP tools. **Important**: Using this flag automatically disables the `run_nushell` tool by default to prevent conflicts between multiple MCP server instances and avoid confusion when the same server provides both generic command execution and specific tools.
- `--enable-run-nushell`
  Explicitly re-enable the `run_nushell` tool when using `--tools-dir`. This creates a hybrid mode where both extension tools and generic nushell command execution are available. Use with caution in multi-instance setups to avoid tool name conflicts.

### Security Options
- `--add-path=PATH` (can be specified multiple times)
  Add additional paths where commands can access files. The current working directory is ALWAYS accessible. Use this flag to grant access to additional paths beyond the current directory. Commands are restricted to the current directory plus any added paths and cannot access files outside them.

## Example Configurations

### Basic Core Mode
```yaml
nu-mcp-core:
  command: "nu-mcp"
  # No args - allows access to current directory only
```

### Core Mode with Additional Paths
```yaml
nu-mcp-core:
  command: "nu-mcp"
  args:
    - "--add-path=/tmp"              # Add /tmp as accessible path
    - "--add-path=/var/log"          # Add /var/log as accessible path
  # Allows access to: current directory + /tmp + /var/log
```

### Extension Mode Only
```yaml
nu-mcp-tools:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
  # Allows access to current directory only
```

### Hybrid Mode
```yaml
nu-mcp-hybrid:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--enable-run-nushell"
  # Allows access to current directory only
```

### With Multiple Additional Paths
```yaml
nu-mcp-multi-sandbox:
  command: "nu-mcp"
  args:
    - "--add-path=/tmp"
    - "--add-path=/var/log"
    - "--add-path=/nix/store"
```

This configuration allows commands to access:
- **Current working directory** (always included)
- `/tmp` and any subdirectories
- `/var/log` and any subdirectories
- `/nix/store` and any subdirectories

Example: If you start the server from `/home/user/myproject`, commands can access:
- `/home/user/myproject` and subdirectories
- `/tmp` and subdirectories
- `/var/log` and subdirectories
- `/nix/store` and subdirectories