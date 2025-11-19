# ArgoCD CLI-Based Authentication Implementation Plan

## Overview

Enhance the existing ArgoCD MCP tool to use `argocd` CLI for transparent authentication management, eliminating the security concerns of passing API tokens in tool calls. The tool will automatically discover ArgoCD instances in the Kubernetes cluster and use the ArgoCD CLI to manage authentication sessions.

## Problem Statement

Current implementation has a critical security flaw: API tokens are passed as clear text in tool call parameters, visible in process lists, shell history, and logs. This violates the zero-conf security model.

## Goals

1. **Secure Authentication**: Use ArgoCD CLI for session management (tokens stored in `~/.argocd/config`)
2. **Zero Configuration**: Auto-discover ArgoCD instances from Kubernetes cluster
3. **Multi-Instance Support**: Handle multiple ArgoCD servers without static configuration
4. **Transparent**: Users don't manually manage tokens or sessions
5. **Maintain Compatibility**: Keep existing tool schemas and functionality

## External Dependencies

- **ArgoCD CLI** (`argocd`): Must be installed and in PATH
- **kubectl**: For Kubernetes API access and secret discovery
- **Kubernetes Cluster**: Access to cluster with ArgoCD instances

## Module Structure

### New Modules

1. **`session.nu`** - CLI-based session/authentication management
   - `get-token`: Get authenticated token for an instance
   - `is-valid`: Check if session is still valid
   - `login`: Login via CLI
   - `read-token`: Extract token from CLI config
   - `ctx-name`: Generate context name for instance

2. **`cluster.nu`** - ArgoCD instance discovery
   - `find`: Discover all ArgoCD instances in cluster
   - `parse`: Parse single instance details
   - `get-server`: Determine server URL
   - `get-creds`: Discover credentials from Kubernetes secrets
   - `resolve`: Resolve instance from tool arguments
   - `cache`: Cache discovered instances

### Modified Modules

3. **`utils.nu`** - Update to use session management
   - Simplify `api-request` to use instance record + session token
   - Remove server/token parameter handling

4. **`applications.nu`** - Update function signatures
   - Change from individual server/token params to instance record
   - Keep kebab-case function names

5. **`resources.nu`** - Update function signatures
   - Change from individual server/token params to instance record
   - Keep kebab-case function names

6. **`mod.nu`** - Update routing logic
   - Add instance resolution before tool execution
   - Update tool calls to pass instance record

## Implementation Milestones

### ✅ Milestone 0: Planning & Research
- [x] Research ArgoCD CLI with Context7
- [x] Create implementation plan document
- [ ] Create feature branch

### Milestone 1: Session Management Module
**File**: `tools/argocd/session.nu`

**Functions** (all kebab-case):
- `get-token [instance: record]` - Main entry point, ensures valid session
- `is-valid [ctx: string, server: string]` - Check session validity
- `login [instance: record]` - Login using CLI
- `read-token [ctx: string]` - Extract token from `~/.argocd/config`
- `ctx-name [instance: record]` - Generate context name

**Acceptance Criteria**:
- [ ] Can login to ArgoCD using CLI with username/password
- [ ] Can read token from `~/.argocd/config`
- [ ] Can validate existing session
- [ ] Handles TLS verification flag from environment
- [ ] Returns clear errors on failure

**Testing**:
```bash
# Manual test with port-forwarded ArgoCD
nu -c "
  use tools/argocd/session.nu *;
  get-token {
    namespace: 'argocd'
    server: 'https://localhost:8080'
    creds: {username: 'admin', password: 'test123'}
  }
"
```

### Milestone 2: Cluster Discovery Module
**File**: `tools/argocd/cluster.nu`

**Functions** (all kebab-case):
- `find []` - Find all ArgoCD instances in cluster
- `parse [ns: string]` - Parse single instance
- `get-server [ns: string]` - Get server URL (LoadBalancer/ClusterIP/annotation)
- `get-creds [ns: string]` - Get credentials from secrets
- `try-secret [ns: string, name: string, transform: closure]` - Secret reader
- `resolve [args: record]` - Resolve instance from tool args
- `cache []` - Cache management with TTL
- `refresh-cache [cache_dir: string, cache_file: string]` - Refresh cache
- `cache-valid [file: string, ttl: duration]` - Check cache validity

**Credential Discovery Strategy** (in order):
1. `argocd-initial-admin-secret` → `{username: "admin", password: <decoded>}`
2. `argocd-mcp-credentials` → `{username: <decoded>, password: <decoded>}`
3. Service annotation `mcp.argocd/credentials-secret` → custom secret

**Acceptance Criteria**:
- [ ] Discovers ArgoCD instances by namespace label
- [ ] Extracts server URL from LoadBalancer/annotations
- [ ] Reads credentials from standard secrets
- [ ] Caches discovered instances for 5 minutes
- [ ] Resolves instance from namespace/server parameters
- [ ] Falls back to current context namespace
- [ ] Returns helpful error if no instances found

**Testing**:
```bash
# Test discovery
nu tools/argocd/cluster.nu -c "use cluster.nu *; find | to json"

# Test resolve
nu -c "
  use tools/argocd/cluster.nu *;
  resolve {namespace: 'argocd'}
"
```

### Milestone 3: Update utils.nu
**File**: `tools/argocd/utils.nu`

**Changes**:
- Import `session.nu`
- Replace `api-request` signature:
  - OLD: `[method, path, server?, token?, --body, --params]`
  - NEW: `[method, path, instance: record, --body, --params]`
- Call `session get-token $instance` internally
- Remove `get-server-url` and `get-auth-token` functions
- Simplify HTTP call logic

**Acceptance Criteria**:
- [ ] `api-request` accepts instance record
- [ ] Transparently gets token via session module
- [ ] Builds URL from instance.server
- [ ] Maintains same error handling

### Milestone 4: Update applications.nu and resources.nu
**Files**: `tools/argocd/applications.nu`, `tools/argocd/resources.nu`

**Changes**:
- Update all exported functions to accept `instance: record` as first parameter
- Remove `server?` and `token?` parameters
- Keep all function names in kebab-case
- Update `api-request` calls to use new signature

**Functions to Update** (applications.nu):
- `list-applications`
- `get-application`
- `create-application`
- `update-application`
- `delete-application`
- `sync-application`

**Functions to Update** (resources.nu):
- `get-resource-tree`
- `get-managed-resources`
- `get-logs`
- `get-application-events`
- `get-events`
- `get-resources`
- `get-resource-actions`
- `run-resource-action`

**Acceptance Criteria**:
- [ ] All functions accept instance as first param
- [ ] All function names remain kebab-case
- [ ] No server/token parameters
- [ ] Calls to api-request updated

### Milestone 5: Update mod.nu Routing
**File**: `tools/argocd/mod.nu`

**Changes**:
- Import `cluster.nu`
- Add instance resolution in `main call-tool`:
  ```nushell
  let instance = cluster resolve $parsed_args
  ```
- Update all tool routing to pass `$instance` to functions
- Remove server/token extraction from parsed_args
- Keep tool names as snake_case (MCP convention)

**Acceptance Criteria**:
- [ ] Resolves instance before routing
- [ ] Passes instance to all tool functions
- [ ] Tool names remain snake_case
- [ ] Function calls remain kebab-case
- [ ] Clear error if instance not found

### Milestone 6: Testing
**Test Scenarios**:

1. **Discovery**:
   - [ ] List discovered instances
   - [ ] Discover from labeled namespace
   - [ ] Cache works and expires correctly

2. **Authentication**:
   - [ ] Login with username/password
   - [ ] Read token from config
   - [ ] Validate existing session
   - [ ] Re-login on expiration

3. **Tool Execution**:
   - [ ] `list_applications` with auto-discovery
   - [ ] `get_application` with explicit namespace
   - [ ] Tools work with cached session
   - [ ] Tools re-authenticate when needed

4. **Error Handling**:
   - [ ] No ArgoCD instances found
   - [ ] Invalid credentials
   - [ ] ArgoCD CLI not installed
   - [ ] Expired session re-authenticates

**Test Commands**:
```bash
# Test discovery
nu tools/argocd/mod.nu list-instances

# Test with auto-discovery (uses current context or first found)
nu tools/argocd/mod.nu call-tool list_applications '{}'

# Test with explicit namespace
nu tools/argocd/mod.nu call-tool list_applications '{"namespace": "argocd"}'

# Test with explicit server
nu tools/argocd/mod.nu call-tool list_applications '{"server": "https://argocd.example.com"}'
```

### Milestone 7: Documentation
**Files to Update**:

1. **`tools/argocd/README.md`**:
   - Document CLI requirement
   - Explain auto-discovery
   - Show credential secret conventions
   - Update configuration examples
   - Remove apiToken parameter docs

2. **Implementation Plan** (this file):
   - Mark all milestones complete
   - Document test results
   - Add lessons learned

**Acceptance Criteria**:
- [ ] README documents ArgoCD CLI requirement
- [ ] Discovery process explained
- [ ] Credential secret patterns documented
- [ ] Examples updated (no more tokens in calls)
- [ ] Security model documented

## Security Considerations

### ✅ Secure
- Credentials stored in Kubernetes secrets
- Tokens managed by ArgoCD CLI in `~/.argocd/config`
- Tokens never passed via command line
- Supports multiple authentication methods (username/password, SSO, etc.)

### Credential Storage Conventions
Recommend these patterns in documentation:

**Option 1: Standard ArgoCD Installation**
```yaml
# Secret: argocd-initial-admin-secret
# Auto-discovered, username="admin"
```

**Option 2: Custom MCP Credentials**
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

**Option 3: Service Annotation**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    mcp.argocd/credentials-secret: custom-secret-name
```

## Error Handling Strategy

### Discovery Errors
- No ArgoCD instances found → Clear error with discovery criteria
- No credentials found → List checked secret names
- Multiple instances, none specified → List available instances

### Authentication Errors
- ArgoCD CLI not found → Installation instructions
- Login failed → Check credentials, server reachability
- Token expired → Auto re-login transparently

### API Errors
- Connection refused → Check port-forward or LoadBalancer
- Unauthorized → Re-authenticate and retry once
- Not found → Clear error with resource details

## Testing Approach

### Unit Testing (Manual)
Test each module independently:
- `session.nu`: Login, token extraction, validation
- `cluster.nu`: Discovery, credential resolution, caching

### Integration Testing
Test complete flows:
- Auto-discovery + authentication + API call
- Explicit namespace + authentication + API call
- Session reuse across multiple calls
- Session expiration and re-authentication

### Edge Cases
- Empty cluster (no ArgoCD)
- Multiple ArgoCD instances
- Expired secrets
- Network failures
- CLI version mismatches

## Rollback Plan

If implementation has issues:
1. Revert to previous commit
2. Keep working on feature branch
3. Address issues before merging

## Success Criteria

- [ ] No API tokens in tool call parameters
- [ ] Auto-discovery works for standard ArgoCD installations
- [ ] Multi-instance support with explicit selection
- [ ] All existing tools work with new authentication
- [ ] Clear error messages for common problems
- [ ] Documentation complete and accurate
- [ ] Tested with real ArgoCD instance

## Timeline Estimate

- Milestone 1 (session.nu): 30 minutes
- Milestone 2 (cluster.nu): 45 minutes
- Milestone 3 (utils.nu): 15 minutes
- Milestone 4 (applications/resources): 30 minutes
- Milestone 5 (mod.nu): 20 minutes
- Milestone 6 (Testing): 45 minutes
- Milestone 7 (Documentation): 30 minutes

**Total**: ~3.5 hours

## Post-Implementation: Token Usage Optimization

### Problem
After initial implementation, discovered that `list_applications` could exceed the 200,000 token limit when returning full ArgoCD application objects. With 11 applications, the full response was ~200,150 tokens, exceeding the limit.

### Solution (Milestone 8)
Implemented automatic summarization following the pattern from `tools/k8s/resources.nu`:

**File**: `tools/argocd/applications.nu`
- Added `summarize-application` function to extract essential fields
- Updated `list-applications` to accept optional `summarize` parameter (default: `true`)
- Summarized apps return only:
  - `name`, `namespace`, `project`
  - `source`: repoURL, path, targetRevision
  - `destination`: server, namespace
  - `syncPolicy.automated`
  - `health.status`
  - `sync.status`, `sync.revision`
  - `createdAt`

**File**: `tools/argocd/formatters.nu`
- Updated `list_applications` schema description
- Added `summarize` boolean parameter (default: true)
- Documented that results are auto-summarized by default

**File**: `tools/argocd/mod.nu`
- Updated routing to pass `summarize` parameter

### Results
- Default behavior: ~90% token reduction for list operations
- Users can opt-in to full objects with `summarize: false`
- Compatible with k8s tools pattern
- No breaking changes (default behavior is the safe option)

### Testing
```bash
# With summarization (default)
nu tools/argocd/mod.nu call-tool list_applications '{"namespace": "argocd"}'

# Without summarization (full objects)
nu tools/argocd/mod.nu call-tool list_applications '{"namespace": "argocd", "summarize": false}'

# Combined with limit
nu tools/argocd/mod.nu call-tool list_applications '{"limit": 5, "summarize": true}'
```

## Lessons Learned

### 1. Token Limits Are Real
Large list responses can easily exceed MCP token limits. Always implement summarization for list operations.

### 2. Follow Existing Patterns
The k8s tools already solved this problem. Reviewing similar tools saves time and ensures consistency.

### 3. Config Path Matters
ArgoCD CLI stores config in `~/.config/argocd/config`, not `~/.argocd/config`. Testing revealed this early.

### 4. URL Format Matters
ArgoCD CLI expects `localhost:8080` format, not `https://localhost:8080`. Strip protocol prefixes.

### 5. Topiary Formatting
Always run `topiary format` after editing Nushell files to maintain code quality standards.

### 6. Default to Safe Behavior
Summarization should be ON by default to prevent token overruns. Let users opt-in to full data.

## References

- ArgoCD CLI Documentation: https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/
- ArgoCD API Documentation: https://argo-cd.readthedocs.io/en/stable/developer-guide/api-docs/
- Tool Development Guide: `docs/tool-development.md`
