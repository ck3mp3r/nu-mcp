# Kubernetes MCP Server

MCP server for Kubernetes cluster management. Provides 22 kubectl/Helm tools with a three-tier safety model.

## Quick Start

**Prerequisites:** kubectl installed and configured with a valid kubeconfig

**Minimal configuration** (uses current context from kubeconfig):
```json
{
  "mcpServers": {
    "k8s": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/k8s"]
    }
  }
}
```

**With explicit context** (recommended):
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
| **readonly** (default) | 7 | No env var needed (or `MCP_K8S_MODE=readonly`) |
| **non-destructive** | 17 | Set `MCP_K8S_MODE=non-destructive` |
| **destructive** | 22 | Set `MCP_K8S_MODE=destructive` |

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

**Non-Destructive Mode** - for deployments and scaling:
```json
{
  "mcpServers": {
    "k8s-staging": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/k8s"],
      "env": {
        "KUBE_CONTEXT": "staging",
        "MCP_K8S_MODE": "non-destructive"
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

**readonly** (default - safest):
- ✅ Only read operations (get, describe, logs, context, explain, list, ping)
- ❌ All write/execute operations

**non-destructive** (safe for most operations):
- ✅ Read operations (get, describe, logs)
- ✅ Create/update operations (apply, scale, patch)
- ✅ Execution (exec, port-forward)
- ✅ Helm install/upgrade
- ❌ Delete operations

**destructive** (development/testing only):
- ✅ All operations including delete, uninstall, cleanup, node drain

## Available Tools

### Read-Only (7 tools)
`kube_get`, `kube_describe`, `kube_logs`, `kube_context`, `kube_explain`, `kube_api_resources`, `kube_ping`

### Non-Destructive Write (10 tools)
`kube_apply`, `kube_create`, `kube_scale`, `kube_patch`, `kube_rollout`, `kube_port_forward`, `kube_port_forward_stop`, `kube_exec`, `helm_install`, `helm_upgrade`

### Destructive (5 tools)
`kube_delete`, `helm_uninstall`, `kube_cleanup`, `kube_generic`, `kube_node`

## Configuration

### Environment Variables

All environment variables are optional:

```bash
# Kubernetes Configuration
KUBECONFIG=/path/to/kubeconfig    # Defaults to ~/.kube/config
KUBE_CONTEXT=my-cluster           # Defaults to current-context in kubeconfig
KUBE_NAMESPACE=default            # Defaults to "default"

# Safety Mode
MCP_K8S_MODE=readonly             # Read-only (default - 7 tools)
MCP_K8S_MODE=non-destructive      # + Non-destructive writes (17 tools)
MCP_K8S_MODE=destructive          # + Destructive operations (22 tools)
```

**Note:** If no environment variables are set, the server will:
- Use `~/.kube/config` as the kubeconfig file
- Use the current-context from that kubeconfig
- Use "default" namespace
- Operate in read-only mode (7 tools)

### Example Configurations

See "Switching Modes" section above for configuration examples.

## Delegation Mode

All kubectl command tools support a `delegate` parameter that returns the command string instead of executing it. This enables LLMs to delegate command execution to other tools (e.g., tmux, remote sessions).

### How Delegation Works

**Normal Execution** (default):
```json
{
  "resourceType": "pods",
  "namespace": "default"
}
// Returns: Pod data (executed)
```

**Delegation Mode**:
```json
{
  "resourceType": "pods",
  "namespace": "default",
  "delegate": true
}
// Returns: "kubectl get pods --namespace default --output json"
```

### Use Cases

**Execute in a tmux pane:**
```
1. LLM calls: kube_get({resourceType: "pods", delegate: true})
   Returns: "kubectl get pods --namespace default --output json"

2. LLM calls: tmux_send_and_capture({
     session: "dev",
     command: "kubectl get pods --namespace default --output json"
   })
   Executes in tmux session
```

**Execute in a remote session:**
- Get kubectl command from k8s tool with `delegate: true`
- Pass command to SSH/remote execution tool
- Command runs in the remote context

### Supported Tools

Delegation is supported in most kubectl command execution tools:
- `kube_get`, `kube_describe`, `kube_logs`
- `kube_apply`, `kube_create`, `kube_patch`
- `kube_scale`, `kube_rollout`, `kube_delete`
- `kube_exec`, and more

**Note:** `kube_port_forward` does not support delegation since port forwarding is a long-running blocking operation that requires process management. Use tmux or similar tools to run port-forward commands directly in background sessions.

**Note:** Delegation respects safety modes - tools will still check permissions before returning commands.

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
nu tools/k8s/mod.nu call-tool kube_get {resourceType: "pods"}
```

## References

- [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes) - Reference implementation
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
