# Kubernetes MCP Server

MCP server for Kubernetes cluster management. Provides 22 kubectl/Helm tools with a three-tier safety model.

## Quick Start

**Prerequisites:** kubectl installed and configured

```json
{
  "mcpServers": {
    "k8s": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "my-cluster"
      }
    }
  }
}
```

## Safety Modes

The server operates in one of three modes based on environment variables:

| Mode | Tools | Configuration |
|------|-------|---------------|
| **Read-Only** (default) | 7 | No env var needed |
| **Non-Destructive** | 17 | Set `MCP_ALLOW_WRITE=true` |
| **Full Access** | 22 | Set `MCP_ALLOW_DESTRUCTIVE=true` |

### Switching Modes

**In your MCP client configuration** (e.g., Claude Desktop, Cline), add the environment variable to the `env` object:

**For write operations** (apply, scale, patch, Helm install):
```json
{
  "mcpServers": {
    "k8s": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "my-cluster",
        "MCP_ALLOW_WRITE": "true"           ← Add this for non-destructive write access
      }
    }
  }
}
```

**For destructive operations** (delete, uninstall):
```json
{
  "env": {
    "KUBE_CONTEXT": "my-cluster",
    "MCP_ALLOW_DESTRUCTIVE": "true"         ← Add this for full access (includes write)
  }
}
```

**Then restart your MCP client** for the change to take effect.

### What Each Mode Allows

**Read-Only Mode** (default - safest):
- ✅ Only read operations (get, describe, logs, context, explain, list, ping)
- ❌ All write/execute operations

**Non-Destructive Mode** (safe for most operations):
- ✅ Read operations (get, describe, logs)
- ✅ Create/update operations (apply, scale, patch)
- ✅ Execution (exec, port-forward)
- ✅ Helm install/upgrade
- ❌ Delete operations

**Full Access Mode** (development/testing only):
- ✅ All operations including delete, uninstall, cleanup, node drain

## Available Tools

### Read-Only (7 tools)
`kubectl_get`, `kubectl_describe`, `kubectl_logs`, `kubectl_context`, `explain_resource`, `list_api_resources`, `ping`

### Non-Destructive Write (10 tools)
`kubectl_apply`, `kubectl_create`, `kubectl_scale`, `kubectl_patch`, `kubectl_rollout`, `port_forward`, `stop_port_forward`, `exec_in_pod`, `helm_install`, `helm_upgrade`

### Destructive (5 tools)
`kubectl_delete`, `helm_uninstall`, `cleanup`, `kubectl_generic`, `node_management`

## Configuration

### Environment Variables

```bash
KUBECONFIG=/path/to/kubeconfig    # Optional - defaults to ~/.kube/config
KUBE_CONTEXT=my-cluster           # Optional - override context
KUBE_NAMESPACE=default            # Optional - default namespace

# Safety modes (default is read-only)
MCP_ALLOW_WRITE=true              # Enable non-destructive write operations
MCP_ALLOW_DESTRUCTIVE=true        # Enable all operations including destructive
```

### Example Configurations

**Production (read-only, default):**
```json
{
  "k8s-prod": {
    "command": "nu-mcp",
    "args": ["--tools-dir", "/path/to/tools/k8s"],
    "env": {
      "KUBE_CONTEXT": "production"
      // No safety flag needed - read-only is default
    }
  }
}
```

**Staging (non-destructive writes):**
```json
{
  "k8s-staging": {
    "command": "nu-mcp",
    "args": ["--tools-dir", "/path/to/tools/k8s"],
    "env": {
      "KUBE_CONTEXT": "staging",
      "MCP_ALLOW_WRITE": "true"
    }
  }
}
```

**Development (full access):**
```json
{
  "k8s-dev": {
    "command": "nu-mcp",
    "args": ["--tools-dir", "/path/to/tools/k8s"],
    "env": {
      "KUBE_CONTEXT": "minikube",
      "MCP_ALLOW_DESTRUCTIVE": "true"
    }
  }
}
```

## Security Features

- **Automatic secret masking**: Sensitive data in secrets is masked
- **Context isolation**: Run multiple server instances with different contexts
- **Namespace isolation**: Limit operations to specific namespaces
- **Safety modes**: Progressive permission model (read-only → non-destructive → full)

## Testing

```bash
# List available tools (shows count based on safety mode)
nu tools/k8s/mod.nu list-tools

# Test connectivity
nu tools/k8s/mod.nu call-tool ping {}

# Get pods
nu tools/k8s/mod.nu call-tool kubectl_get {resourceType: "pods"}
```

## References

- [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes) - Reference implementation
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
