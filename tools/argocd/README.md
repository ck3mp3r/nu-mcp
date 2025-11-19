# ArgoCD MCP Server

MCP server for ArgoCD with automatic discovery and CLI-based authentication.

## Features

- **Zero Configuration**: Automatically discovers ArgoCD instances in your Kubernetes cluster
- **Secure Authentication**: Uses `argocd` CLI for session management (no tokens in tool calls)
- **Multi-Instance Support**: Can work with multiple ArgoCD servers
- **Safety Modes**: Read-only by default, with controlled write access

## Requirements

- **ArgoCD CLI** (`argocd`) - Must be installed and in PATH
- **kubectl** - For Kubernetes cluster access
- **Kubernetes Cluster** - With ArgoCD installed

### Installing ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Verify installation
argocd version
```

## How It Works

1. **Discovery**: The tool scans your Kubernetes cluster for ArgoCD installations
2. **Credential Discovery**: Finds credentials from Kubernetes secrets
3. **CLI Authentication**: Uses `argocd login` to create sessions
4. **Token Management**: ArgoCD CLI stores tokens in `~/.argocd/config`
5. **API Calls**: Makes HTTP API calls using CLI-managed tokens

## Credential Discovery

The tool automatically discovers credentials using these strategies (in order):

### 1. Standard ArgoCD Installation
```yaml
# Secret: argocd-initial-admin-secret
# Automatically created by ArgoCD
# Username: admin
```

### 2. Custom MCP Credentials (Recommended)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-mcp-credentials
  namespace: argocd
type: Opaque
stringData:
  username: mcp-user
  password: <secure-password>
```

### 3. Service Annotation
```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    mcp.argocd/credentials-secret: custom-credentials
```

## Configuration

### Environment Variables

- `TLS_REJECT_UNAUTHORIZED` (optional) - Set to `"0"` for self-signed certificates
- `MCP_READ_ONLY` (optional) - Set to `"false"` to enable write operations (default: `"true"`)

### MCP Client Configuration

Minimal configuration - no credentials needed!

```json
{
  "mcpServers": {
    "argocd": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/argocd"],
      "env": {
        "TLS_REJECT_UNAUTHORIZED": "0",
        "MCP_READ_ONLY": "false"
      }
    }
  }
}
```

## Available Tools

### Read-Only (9 tools)
- `list_applications` - List all applications
- `get_application` - Get application details
- `get_application_resource_tree` - Get resource hierarchy
- `get_application_managed_resources` - List managed resources
- `get_application_workload_logs` - Get pod/deployment logs
- `get_application_events` - Get application events
- `get_resource_events` - Get resource-specific events
- `get_resources` - Get resource manifests
- `get_resource_actions` - List available resource actions

### Write Operations (5 tools)
Disabled by default. Enable with `MCP_READ_ONLY="false"`:
- `create_application` - Create new application
- `update_application` - Update application
- `delete_application` - Delete application
- `sync_application` - Trigger sync operation
- `run_resource_action` - Execute resource action

## Usage

### Auto-Discovery (Default)

The tool automatically discovers and authenticates to ArgoCD:

```bash
# List discovered ArgoCD instances
nu tools/argocd/mod.nu list-instances

# List applications (auto-discovers from current kubectl context)
nu tools/argocd/mod.nu call-tool list_applications '{}'

# Get application details
nu tools/argocd/mod.nu call-tool get_application '{"applicationName": "my-app"}'
```

### Explicit Instance Selection

Specify which ArgoCD instance to use:

```bash
# By namespace
nu tools/argocd/mod.nu call-tool list_applications '{"namespace": "argocd-prod"}'

# By server URL
nu tools/argocd/mod.nu call-tool list_applications '{"server": "https://argocd.example.com"}'
```

## Testing

### With Port-Forward (Development)

```bash
# Port-forward to local ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Set environment for self-signed certs
export TLS_REJECT_UNAUTHORIZED="0"

# Test discovery
nu tools/argocd/mod.nu list-instances

# Test tool calls
nu tools/argocd/mod.nu call-tool list_applications '{}'
```

### With LoadBalancer (Production)

```bash
# Tool automatically discovers LoadBalancer IP
nu tools/argocd/mod.nu list-instances

# Use discovered instance
nu tools/argocd/mod.nu call-tool list_applications '{}'
```

## Troubleshooting

### ArgoCD CLI Not Found

```
Error: Failed to login to ArgoCD: External command failed
```

**Solution**: Install ArgoCD CLI (see Requirements section)

### No ArgoCD Instances Found

```
Error: No ArgoCD instances found in cluster
```

**Solutions**:
- Label your ArgoCD namespace: `kubectl label namespace argocd app.kubernetes.io/part-of=argocd`
- Specify namespace explicitly in tool call: `{"namespace": "argocd"}`

### No Credentials Found

```
Error: No credentials found for ArgoCD in namespace argocd
```

**Solutions**:
- Check if `argocd-initial-admin-secret` exists
- Create `argocd-mcp-credentials` secret (see Credential Discovery section)

### Token Expired

The tool automatically re-authenticates when tokens expire. No manual intervention needed.

## Security

✅ **Secure**:
- Credentials stored in Kubernetes secrets
- Tokens managed by ArgoCD CLI in `~/.argocd/config`
- No tokens passed via command-line arguments
- Leverages Kubernetes RBAC

✅ **Transparent**:
- Auto-discovery eliminates manual configuration
- Auto-authentication eliminates token management
- Multi-instance support without static config
