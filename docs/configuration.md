# Configuration

## Command-Line Options

### Extension System
- `--tools-dir=PATH` (`-t PATH`) - Load tools from directory. **Note:** Disables the `run` tool by default to avoid conflicts in multi-instance setups.
- `--enable-nu` (`-e`) - Re-enable the `run` tool when using `--tools-dir` (hybrid mode).

### Security
- `--add-path=PATH` (`-p PATH`) - Grant read-write access to additional paths beyond the current directory (can be used multiple times).
- `--add-read-path=PATH` (`-r PATH`) - Grant read-only access to additional paths (can be used multiple times).
- `--block-network` (`-n`) - Block all network access for sandboxed commands.
- `--bypass-protection=PATH` (`-b PATH`) - Unblock a sensitive path (can be used multiple times).
- `--allow-binary=NAME` (`-a NAME`) - Allow an external binary in the sandbox (can be specified multiple times).

## Environment Variables

### Timeout
- `MCP_NU_MCP_TIMEOUT` - Default timeout in seconds for all tools (default: 300)
- Can be overridden per-call with `timeout_seconds` parameter on the `run` tool

**Example:**
```yaml
nu-mcp:
  command: "nu-mcp"
  env:
    MCP_NU_MCP_TIMEOUT: "120"
```

## Usage Modes

### Core Mode
Nushell command execution with one-shot processes:
```yaml
nu-mcp-core:
  command: "nu-mcp"
```

The `run` tool runs each command in a stateless one-shot process. Environment variables, aliases, and definitions do not persist across calls.

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
    - "--enable-nu"
```

### With Additional Paths
```yaml
nu-mcp-extended:
  command: "nu-mcp"
  args:
    - "--add-path=/tmp"
    - "--add-read-path=/var/log"
    - "--block-network"
```

Grants read-write access to the current directory and `/tmp`, and read-only access to `/var/log`. Network access is blocked.
