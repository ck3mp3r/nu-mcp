# Configuration

## Command-Line Options

### Extension System
- `--tools-dir=PATH` - Load tools from directory. **Note:** Disables `run` by default to avoid conflicts in multi-instance setups.
- `--enable-run-nu` - Re-enable `run` when using `--tools-dir` (hybrid mode).

### Security
- `--add-path=PATH` - Grant access to additional paths beyond current directory (can be used multiple times).

## Environment Variables

### Timeout
- `MCP_NU_MCP_TIMEOUT` - Default timeout in seconds for all tools (default: 60)
- Can be overridden per-call with `timeout_seconds` parameter on `run` tool

### Debugging
- `MCP_PTY_TRACE` - Set to `1` to enable PTY trace logging to `/tmp/pty_trace.log` (persistent mode only)

**Example:**
```yaml
nu-mcp:
  command: "nu-mcp"
  env:
    MCP_NU_MCP_TIMEOUT: "120"
```

## Usage Modes

### Core Mode
Nushell command execution with persistent state:
```yaml
nu-mcp-core:
  command: "nu-mcp"
```

The `run` tool maintains a persistent Nushell shell. Environment variables, aliases, and definitions persist across calls. Use the `reset` parameter to get a clean shell when needed.

### Extension Mode
Tool-specific functionality:
```yaml
nu-mcp-tools:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
```

### Hybrid Mode
Both generic commands and tools:
```yaml
nu-mcp-hybrid:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--enable-run-nu"
```

### With Additional Paths
```yaml
nu-mcp-extended:
  command: "nu-mcp"
  args:
    - "--add-path=/tmp"
    - "--add-path=/var/log"
```

Allows access to current directory + `/tmp` + `/var/log`
