# Configuration Guide

The `nu-mcp` server is configured via command-line arguments or by passing arguments as part of a process launch configuration.

## Command Line Options

### Extension System Options
- `--tools-dir=PATH`
  Directory containing tool modules. When specified, the server automatically discovers and loads all directories containing `mod.nu` files as MCP tools. **Important**: Using this flag automatically disables the `run_nushell` tool by default to prevent conflicts between multiple MCP server instances and avoid confusion when the same server provides both generic command execution and specific tools.
- `--enable-run-nushell`
  Explicitly re-enable the `run_nushell` tool when using `--tools-dir`. This creates a hybrid mode where both extension tools and generic nushell command execution are available. Use with caution in multi-instance setups to avoid tool name conflicts.

### Security Options
- `--sandbox-dir=PATH` (can be specified multiple times)
  **Additional** directories where commands can access files. The current working directory is ALWAYS included. Use this flag to grant access to additional directories beyond the current directory. Commands are restricted to the current directory plus any specified sandbox directories and cannot access files outside them.

## Example Configurations

### Basic Core Mode
```yaml
nu-mcp-core:
  command: "nu-mcp"
  # No args - allows access to current directory only
```

### Core Mode with Additional Directories
```yaml
nu-mcp-core:
  command: "nu-mcp"
  args:
    - "--sandbox-dir=/tmp"              # Add /tmp as allowed directory
    - "--sandbox-dir=/var/log"          # Add /var/log as allowed directory
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

### With Multiple Additional Sandboxes
```yaml
nu-mcp-multi-sandbox:
  command: "nu-mcp"
  args:
    - "--sandbox-dir=/tmp"
    - "--sandbox-dir=/var/log"
    - "--sandbox-dir=/nix/store"
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