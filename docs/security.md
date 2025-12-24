# Security

## Sandbox Model

**Current working directory is ALWAYS accessible.** Use `--add-path` to grant access to additional paths.

### Path Restrictions
- Commands execute within sandbox directories (current dir + added paths)
- Path traversal (`../`) is allowed if it stays within sandbox boundaries
- Absolute paths outside sandbox are blocked
- Symlinks are resolved before validation

### Example
```bash
# From /home/user/project
nu-mcp --add-path=/tmp --add-path=/var/log
```

**Accessible:**
- ✅ `/home/user/project/**` (current directory)
- ✅ `/tmp/**` (added)
- ✅ `/var/log/**` (added)

**Blocked:**
- ❌ `/etc/passwd`
- ❌ `/home/user/other-project/**`

## Safe Command Patterns

Some commands use path-like strings that aren't filesystem paths (API endpoints, resource IDs). These bypass path validation:

### Whitelisted Patterns
- `gh api /repos/...` - GitHub API endpoints
- `kubectl get /apis/...` - Kubernetes resource paths
- `argocd app get /argocd/...` - ArgoCD application paths
- `curl https://...` - HTTP URLs
- `http get https://...` - Nushell HTTP commands

### Adding New Patterns

Edit `src/security/safe_command_patterns.txt`:
```regex
# Your tool - API endpoints only
^your-tool\s+api\s+/
```

**Requirements:**
- Pattern must match NON-filesystem paths only
- Add tests in `src/security/mod_test.rs`
- Run `cargo test`
- Rebuild (patterns embedded at compile time)

## Quote-Aware Validation

Content inside quotes is NOT validated as filesystem paths:

**Allowed:**
- `echo "The file /etc/passwd is important"` ✅
- `gh pr create --body "Fixed /etc/config"` ✅
- URLs: `curl https://example.com/api` ✅

**Blocked:**
- `cat /etc/passwd` ❌ (bare absolute path)
- `ls ../../../../etc` ❌ (escapes sandbox)

## Path Caching

Non-existent paths outside sandbox are cached for performance (e.g., API endpoints like `/metrics`). Cache is session-scoped, in-memory only.

**Security guarantee:** Existing files outside sandbox are always blocked, never cached.

## Tool Security

- Tools run in same security context as server
- Tools can access environment variables
- Tools can spawn processes within sandbox
- Review tool implementations before deployment

## Disclaimer

**USE AT YOUR OWN RISK.** This software is provided "as is" without warranty. Users are responsible for:
- Understanding security implications
- Proper sandbox configuration
- Testing in non-production environments
- Monitoring and securing systems
- All consequences from command execution
