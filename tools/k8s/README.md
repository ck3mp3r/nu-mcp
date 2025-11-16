# Kubernetes MCP Server

MCP server for Kubernetes cluster management using kubectl. Based on [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes).

## Features

- **Three-Tier Safety Model**: Read-only, non-destructive (default), and full access modes
- **22 Kubernetes Tools**: Comprehensive kubectl operations
- **Nushell-Native**: Structured data handling with Nushell
- **Secret Masking**: Automatic masking of sensitive data

## Safety Model

### Default: Non-Destructive Mode (17 tools)

By default, the server operates in non-destructive mode with **no environment variables required**.

**Allowed Operations**:
- ✅ All read operations (get, describe, logs, etc.)
- ✅ Create/update operations (apply, create, scale, patch)
- ✅ Execution operations (exec, port-forward)
- ✅ Helm install/upgrade
- ❌ Delete operations (delete, uninstall, cleanup)

### Opt-In: Read-Only Mode (7 tools)

For maximum safety, enable read-only mode:

```bash
export MCP_READ_ONLY=true
```

**Allowed Operations**:
- ✅ Only read operations
- ❌ All write/execute operations

### Opt-In: Full Access Mode (22 tools)

For development/testing environments:

```bash
export MCP_ALLOW_DESTRUCTIVE=true
```

**Allowed Operations**:
- ✅ All operations including delete

## Configuration

### Environment Variables

```bash
# kubectl Configuration
KUBECONFIG=/path/to/kubeconfig    # Optional - defaults to ~/.kube/config
KUBE_CONTEXT=my-cluster           # Optional - override context
KUBE_NAMESPACE=default            # Optional - default namespace

# Safety Configuration (choose one)
MCP_READ_ONLY=true                # Opt-in: Read-only mode (7 tools)
MCP_ALLOW_DESTRUCTIVE=true        # Opt-in: Full access (22 tools)
# (no flags)                      # Default: Non-destructive (17 tools)
```

### MCP Client Configuration

#### Default (Non-Destructive - Recommended)

```json
{
  "mcpServers": {
    "k8s": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/k8s"],
      "env": {
        "KUBECONFIG": "/home/user/.kube/config",
        "KUBE_CONTEXT": "production",
        "KUBE_NAMESPACE": "default"
      }
    }
  }
}
```

#### Read-Only Mode

```json
{
  "mcpServers": {
    "k8s-readonly": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/k8s"],
      "env": {
        "KUBECONFIG": "/home/user/.kube/config",
        "KUBE_CONTEXT": "production",
        "MCP_READ_ONLY": "true"
      }
    }
  }
}
```

#### Full Access Mode (Dev/Test)

```json
{
  "mcpServers": {
    "k8s-dev": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/k8s"],
      "env": {
        "KUBECONFIG": "/home/user/.kube/config-dev",
        "KUBE_CONTEXT": "minikube",
        "MCP_ALLOW_DESTRUCTIVE": "true"
      }
    }
  }
}
```

## Available Tools

### Phase 1A: Read-Only Operations (7 tools)

All modes support these tools:

| Tool | Description |
|------|-------------|
| `kubectl_get` | Get/list Kubernetes resources |
| `kubectl_describe` | Describe resource details |
| `kubectl_logs` | Get pod/container logs |
| `kubectl_context` | Manage kubeconfig contexts |
| `explain_resource` | Explain Kubernetes resource types |
| `list_api_resources` | List available API resources |
| `ping` | Verify kubectl connectivity |

### Phase 1B: Non-Destructive Operations (10 tools)

Available in non-destructive and full access modes:

| Tool | Description |
|------|-------------|
| `kubectl_apply` | Apply YAML manifests |
| `kubectl_create` | Create resources |
| `kubectl_scale` | Scale replicas |
| `kubectl_patch` | Update resource fields |
| `kubectl_rollout` | Rollout operations |
| `port_forward` | Port forward to pod/service |
| `stop_port_forward` | Stop port forwarding |
| `exec_in_pod` | Execute commands in pods |
| `install_helm_chart` | Install Helm chart |
| `upgrade_helm_chart` | Upgrade Helm release |

### Phase 2: Destructive Operations (5 tools)

Available only in full access mode:

| Tool | Description |
|------|-------------|
| `kubectl_delete` | Delete resources |
| `uninstall_helm_chart` | Uninstall Helm releases |
| `cleanup_pods` | Cleanup failed/evicted pods |
| `kubectl_generic` | Generic kubectl commands |
| `node_management` | Cordon/drain/uncordon nodes |

## Prerequisites

1. **kubectl** installed and in your PATH
2. Valid kubeconfig file with contexts configured
3. Access to a Kubernetes cluster
4. **helm** (optional, for Helm operations)

Verify your setup:

```bash
# Check kubectl
kubectl version --client

# Verify cluster access
kubectl cluster-info

# List contexts
kubectl config get-contexts
```

## Testing

### Manual Testing

```bash
# List available tools
source mod.nu
main list-tools

# Test connectivity
main call-tool ping {}

# List pods in default namespace
main call-tool kubectl_get {resourceType: "pods"}

# Get specific pod
main call-tool kubectl_get {
    resourceType: "pods"
    name: "my-pod"
    namespace: "default"
}

# Get pod logs
main call-tool kubectl_logs {
    name: "my-pod"
    namespace: "default"
    tail: 100
}

# Describe a deployment
main call-tool kubectl_describe {
    resourceType: "deployment"
    name: "my-deployment"
    namespace: "default"
}

# List contexts
main call-tool kubectl_context {operation: "list"}

# Explain pod spec
main call-tool explain_resource {resource: "pod.spec"}
```

### Safety Mode Testing

```bash
# Test read-only mode
MCP_READ_ONLY=true source mod.nu
main list-tools  # Should show 7 tools

# Test non-destructive mode (default)
source mod.nu
main list-tools  # Should show 17 tools

# Test full access
MCP_ALLOW_DESTRUCTIVE=true source mod.nu
main list-tools  # Should show 22 tools

# Verify delete is blocked in non-destructive mode
main call-tool kubectl_delete {resourceType: "pod", name: "test"}
# Should return PermissionDenied error
```

### Local Cluster Setup

For testing, you can use:

```bash
# Minikube
minikube start

# Kind
kind create cluster --name test-mcp

# K3d
k3d cluster create test-mcp
```

## Examples

### Get all pods with labels

```bash
main call-tool kubectl_get {
    resourceType: "pods"
    allNamespaces: true
    labelSelector: "app=nginx"
    output: "json"
}
```

### Get recent logs with timestamps

```bash
main call-tool kubectl_logs {
    name: "my-pod"
    namespace: "production"
    tail: 200
    timestamps: true
    since: "1h"
}
```

### Switch context

```bash
main call-tool kubectl_context {
    operation: "use"
    name: "dev-cluster"
}
```

### List deployments across all namespaces

```bash
main call-tool kubectl_get {
    resourceType: "deployments"
    allNamespaces: true
    output: "wide"
}
```

## Security Considerations

### Secret Masking

The server automatically masks sensitive data when retrieving secrets:

```bash
main call-tool kubectl_get {
    resourceType: "secrets"
    namespace: "default"
}
# Secret data values will be replaced with "***MASKED***"
```

### Context Isolation

Each MCP server instance can use a different context:

```json
{
  "mcpServers": {
    "k8s-prod": {
      "env": { "KUBE_CONTEXT": "production", "MCP_READ_ONLY": "true" }
    },
    "k8s-dev": {
      "env": { "KUBE_CONTEXT": "development", "MCP_ALLOW_DESTRUCTIVE": "true" }
    }
  }
}
```

### Namespace Isolation

Limit operations to a specific namespace:

```json
{
  "env": {
    "KUBE_NAMESPACE": "my-namespace",
    "MCP_READ_ONLY": "true"
  }
}
```

## Troubleshooting

### kubectl not found

```bash
# Install kubectl
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Cannot connect to cluster

```bash
# Check kubeconfig
kubectl config view

# Test cluster connectivity
kubectl cluster-info

# Check current context
kubectl config current-context
```

### Permission denied errors

Check your safety mode setting:

```bash
# Current mode
echo $env.MCP_READ_ONLY?
echo $env.MCP_ALLOW_DESTRUCTIVE?

# Allow write operations
export MCP_ALLOW_DESTRUCTIVE=true
```

## Development Status

- ✅ **Phase 1A**: Core read operations (7 tools) - **Complete**
- ⏳ **Phase 1B**: Non-destructive write operations (10 tools) - **Planned**
- ⏳ **Phase 2**: Destructive operations (5 tools) - **Planned**

## References

- [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes) - Reference implementation
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/) - kubectl reference
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification
