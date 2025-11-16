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
| **Non-Destructive** (default) | 17 | No env var needed |
| **Read-Only** | 7 | Set `MCP_READ_ONLY=true` |
| **Full Access** | 22 | Set `MCP_ALLOW_DESTRUCTIVE=true` |

### Switching Modes

**In your MCP client configuration** (e.g., Claude Desktop, Cline), add the environment variable to the `env` object:

```json
{
  "mcpServers": {
    "k8s": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "my-cluster",
        "MCP_ALLOW_DESTRUCTIVE": "true"     ← Add this line for full access
      }
    }
  }
}
```

**Then restart your MCP client** for the change to take effect.

### What Each Mode Allows

**Non-Destructive Mode** (default - safest for production):
- ✅ Read operations (get, describe, logs)
- ✅ Create/update operations (apply, scale, patch)
- ✅ Execution (exec, port-forward)
- ✅ Helm install/upgrade
- ❌ Delete operations

**Read-Only Mode** (maximum safety):
- ✅ Only read operations (get, describe, logs, context, explain, list, ping)
- ❌ All write/execute operations

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

# Safety modes
MCP_READ_ONLY=true                # Enable read-only mode
MCP_ALLOW_DESTRUCTIVE=true        # Enable destructive operations
```

### Example Configurations

**Production (read-only):**
```json
{
  "k8s-prod": {
    "command": "nu-mcp",
    "args": ["--tools-dir", "/path/to/tools/k8s"],
    "env": {
      "KUBE_CONTEXT": "production",
      "MCP_READ_ONLY": "true"
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
