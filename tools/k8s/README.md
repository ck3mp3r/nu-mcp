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

The server operates in one of three modes controlled by a single environment variable:

| Mode | Tools | Configuration |
|------|-------|---------------|
| **Read-Only** (default) | 7 | No env var needed (or `MCP_K8S_MODE=readonly`) |
| **Write** | 17 | Set `MCP_K8S_MODE=write` |
| **Destructive** | 22 | Set `MCP_K8S_MODE=destructive` |

### Switching Modes

Set `MCP_K8S_MODE` in your MCP client configuration (e.g., Claude Desktop, Cline):

**Read-Only (default)** - safest for production:
```json
{
  "mcpServers": {
    "k8s-prod": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "production"
        // No MCP_K8S_MODE needed - defaults to readonly
      }
    }
  }
}
```

**Write Mode** - for deployments and scaling:
```json
{
  "mcpServers": {
    "k8s-staging": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "staging",
        "MCP_K8S_MODE": "write"
      }
    }
  }
}
```

**Destructive Mode** - development/testing only:
```json
{
  "mcpServers": {
    "k8s-dev": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "minikube",
        "MCP_K8S_MODE": "destructive"
      }
    }
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

# Safety mode (default is readonly)
MCP_K8S_MODE=readonly             # Read-only access (default)
MCP_K8S_MODE=write                # Non-destructive write operations
MCP_K8S_MODE=destructive          # All operations including delete
```

### Example Configurations

See "Switching Modes" section above for configuration examples.

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
