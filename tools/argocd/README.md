# ArgoCD MCP Server

MCP server for ArgoCD with automatic discovery and CLI-based authentication.

## Features

- **Zero Configuration**: Automatically discovers ArgoCD instances in your Kubernetes cluster
- **Secure Authentication**: Uses `argocd` CLI for session management (no tokens in tool calls)
- **Multi-Instance Support**: Can work with multiple ArgoCD servers
- **Safety Modes**: Read-only by default, with controlled write access

## Requirements

**Critical**: These tools will **NOT work** without the ArgoCD CLI installed and available on PATH.

- **ArgoCD CLI** (`argocd`) - **REQUIRED** - Must be installed and on PATH at runtime
- **kubectl** - For Kubernetes cluster access
- **Kubernetes Cluster** - With ArgoCD installed

### Installing ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Nix / NixOS
nix-shell -p argocd
# Or add to your environment

# Verify installation
argocd version
```

**Note**: If using via Nix devenv (this repository), `argocd` is automatically available in the shell.

## How It Works

1. **Discovery**: The tool scans your Kubernetes cluster for ArgoCD installations
2. **URL Detection**: Checks for accessible URLs (external annotation, LoadBalancer IP/hostname)
3. **Port-Forward Instructions**: If no accessible URL, instructs LLM to setup port-forward via k8s tool
4. **Credential Discovery**: Finds credentials from Kubernetes secrets
5. **CLI Authentication**: Uses `argocd login` to create sessions
6. **Token Management**: ArgoCD CLI stores tokens in `~/.argocd/config`
7. **API Calls**: Makes HTTP API calls using CLI-managed tokens

### Authentication Modes

**Mode 1: Server only** - User already logged in
```bash
{"server": "https://argocd.example.com"}
# Assumes: argocd login argocd.example.com (already done)
```

**Mode 2: Server + Namespace** - Auto-login
```bash
{"server": "https://localhost:8080", "namespace": "argocd"}
# Tool discovers credentials from namespace and logs in automatically
```

**Mode 3: Namespace only** - Full auto-discovery
```bash
{"namespace": "argocd"}
# Tool discovers server URL from k8s service, credentials from secrets, logs in
# If no accessible URL → errors with port-forward instructions for LLM
```

**Mode 4: No parameters** - Complete auto-discovery
```bash
{}
# Tool discovers everything from current kubectl context
# If no accessible URL → errors with port-forward instructions for LLM
```

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

### Port-Forward Workflow (Recommended for Development)

**Step 1: Set up port-forward using k8s tools**
```bash
# Use k8s MCP tools or kubectl directly
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

**Step 2: Use ArgoCD tools with explicit server + namespace**
```bash
# Call ArgoCD tools with server and namespace
# Note: TLS verification is automatically disabled for localhost URLs
nu tools/argocd/mod.nu call-tool list_applications '{
  "server": "https://localhost:8080",
  "namespace": "argocd"
}'

# Get specific application
nu tools/argocd/mod.nu call-tool get_application '{
  "applicationName": "my-app",
  "server": "https://localhost:8080",
  "namespace": "argocd"
}'
```

**Why both parameters?**
- `server`: The URL to connect to (localhost from port-forward)
- `namespace`: Where to discover credentials from Kubernetes secrets

This clean separation means:
- You control the port-forward with k8s tools
- ArgoCD tools just need to know the URL and where to find credentials
- No magic, no auto-discovery complexity for local dev

### LoadBalancer/Ingress Workflow (Production)

**Option 1: Auto-Discovery (discovers server URL from k8s)**
```bash
# List all discovered ArgoCD instances
nu tools/argocd/mod.nu list-instances

# Use auto-discovery by namespace only
nu tools/argocd/mod.nu call-tool list_applications '{
  "namespace": "argocd-prod"
}'
```

**Option 2: Explicit Server URL**
```bash
# Provide external URL + namespace for credentials
nu tools/argocd/mod.nu call-tool list_applications '{
  "server": "https://argocd.example.com",
  "namespace": "argocd-prod"
}'
```

### Auto-Discovery Only (Legacy)

Let the tool discover both server and credentials:

```bash
# Uses current kubectl context namespace
nu tools/argocd/mod.nu call-tool list_applications '{}'

# Or specify namespace to discover from
nu tools/argocd/mod.nu call-tool list_applications '{"namespace": "argocd"}'
```

**Note**: Auto-discovery works for LoadBalancer services but is unnecessary when you're already port-forwarding.

### Token Usage Optimization

By default, `list_applications` returns summarized results to reduce token usage:

```bash
# Default: summarized (only essential fields)
nu tools/argocd/mod.nu call-tool list_applications '{
  "namespace": "argocd",
  "limit": 10
}'

# Full objects (use sparingly, consumes many tokens)
nu tools/argocd/mod.nu call-tool list_applications '{
  "namespace": "argocd",
  "summarize": false,
  "limit": 2
}'
```

**Token savings**: Summarization reduces token usage by ~90% (70k vs 200k+ for 11 apps)

## Troubleshooting

### ArgoCD CLI Not Found

```
Error: Failed to login to ArgoCD: External command failed
```

**Solution**: Install ArgoCD CLI (see Requirements section)

### Connection Refused (Port-Forward)

```
Error: API request failed: I/O error
```

**Solutions**:
1. Verify port-forward is running: `ps aux | grep "kubectl.*port-forward.*argocd"`
2. Check you're using the correct port in `server` parameter

**Correct workflow**:
```bash
# 1. Start port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# 2. Use that port in your tool call (TLS is auto-disabled for localhost)
nu tools/argocd/mod.nu call-tool list_applications '{
  "server": "https://localhost:8080",
  "namespace": "argocd"
}'
```

### No ArgoCD Instances Found

```
Error: No ArgoCD instances found in cluster
```

**When this happens**:
- You're using auto-discovery (no `server` parameter provided)
- The tool can't find ArgoCD in your cluster

**Solutions**:
1. **Use explicit server** (recommended for port-forward):
   ```bash
   {"server": "https://localhost:8080", "namespace": "argocd"}
   ```

2. **Or fix discovery** by labeling namespace:
   ```bash
   kubectl label namespace argocd app.kubernetes.io/part-of=argocd
   ```

### No Credentials Found

```
Error: No credentials found for ArgoCD in namespace argocd
```

**Solutions**:
- Check if `argocd-initial-admin-secret` exists: `kubectl get secret -n argocd argocd-initial-admin-secret`
- Create `argocd-mcp-credentials` secret (see Credential Discovery section)

### Token Limit Exceeded

```
Error: prompt is too long: 200150 tokens > 200000 maximum
```

**Solution**: Use summarization (enabled by default):
```bash
# Summarized results (default)
{"namespace": "argocd", "limit": 10}

# Or explicit
{"namespace": "argocd", "summarize": true}
```

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
