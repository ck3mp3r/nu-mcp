# ArgoCD MCP Server

MCP server for ArgoCD using the HTTP API. Based on [argoproj-labs/mcp-for-argocd](https://github.com/argoproj-labs/mcp-for-argocd).

## Configuration

### Environment Variables

- `ARGOCD_BASE_URL` (required) - ArgoCD server URL
- `ARGOCD_API_TOKEN` (required) - API authentication token
- `TLS_REJECT_UNAUTHORIZED` (optional) - Set to `"0"` for self-signed certificates
- `MCP_READ_ONLY` (optional) - Read-only by default. Set to `"false"` to enable write operations

### Getting an API Token

```bash
argocd login <server>
# Token stored in ~/.config/argocd/config
```

### MCP Client Configuration

Add to your MCP configuration file:

```json
{
  "mcpServers": {
    "argocd": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/argocd"],
      "env": {
        "ARGOCD_BASE_URL": "https://argocd.example.com",
        "ARGOCD_API_TOKEN": "<your-token>",
        "TLS_REJECT_UNAUTHORIZED": "0",
        "MCP_READ_ONLY": "false"
      }
    }
  }
}
```

Note: The server is read-only by default. Set `MCP_READ_ONLY: "false"` to enable write operations.

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

## Testing

```bash
export ARGOCD_BASE_URL="https://argocd.example.com"
export ARGOCD_API_TOKEN="<token>"
export TLS_REJECT_UNAUTHORIZED="0"

# List applications
source mod.nu
main call-tool list_applications {}

# Get application details
main call-tool get_application {applicationName: "my-app"}
```
