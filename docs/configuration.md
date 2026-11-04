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
- `--disable-sandbox` - Disable self-sandboxing. The capability set is never built and never applied, so `--block-network` and all path grants are unenforced. Use it only when the server already runs inside a sandbox. See [security.md](security.md#disabling-the-sandbox).

### Credentials
- `--env-credential=REF=ENV_VAR` - Resolve a credential and inject it into the server environment (can be specified multiple times).
- `--keyring-service=SERVICE` - Keyring service name used for bare credential names (default: `nono`, the nono keystore default service).

Each `--env-credential` value splits at its **last** `=`: everything before it is the credential reference, everything after it is the destination variable name. Trimmed halves must be non-empty, and the destination name must match `[A-Za-z0-9_]+` and must not be a dangerous variable such as `PATH` or `LD_PRELOAD`.

The reference may itself contain `=`. Supported schemes:

| Reference | Source |
|-----------|--------|
| `env://VAR` | An existing environment variable |
| `file:///absolute/path` | A file; the trailing newline is stripped |
| `keyring://service/account` | The system keyring |
| `op://vault/item/field` | 1Password CLI (`op`) |
| `bw://item[/field]` | Bitwarden CLI (`bw`) |
| `apple-password://server/account` | Apple Passwords |
| `bare-keyring-name` | Keyring account under `--keyring-service` |

Credentials are resolved during startup, before the sandbox is applied, because the secret brokers (`op`, `bw`, `security`) need host access. A reference that cannot be resolved aborts startup.

```yaml
nu-mcp:
  command: "nu-mcp"
  args:
    - "--env-credential=op://Private/github/token=GITHUB_TOKEN"
    - "--env-credential=file:///run/secrets/api-token=API_TOKEN"
```

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
