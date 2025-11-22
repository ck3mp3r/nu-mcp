# Safe Command Allowlist Expansion Plan

## Overview

Expand the safe command pattern allowlist with comprehensive read-only operations from common CLI tools. Update terminology from "whitelist/blacklist" to "allowlist/denylist" throughout the codebase.

## Current State

The allowlist currently includes:
1. `gh api` - GitHub API endpoints  
2. `kubectl <verb> /api*` - Kubernetes API resources
3. `argocd app <cmd> /argocd/*` - ArgoCD application paths
4. `curl/wget/http <url>` - HTTP clients with URLs
5. `http <verb> <url>` - Nushell HTTP commands

## Terminology Updates

### Files to Update

1. **src/security/mod.rs**
   - Rename `get_safe_command_patterns()` → keep as is (already neutral)
   - Update comments: "whitelist" → "allowlist"
   - Update function docs

2. **docs/security.md**
   - Replace "whitelist" → "allowlist"
   - Replace "Safe Command Whitelist" → "Safe Command Allowlist"
   - Update section headings and terminology

3. **src/security/mod_test.rs**
   - Update test names: `*_whitelisted` → `*_in_allowlist`
   - Update assertion messages

4. **Commit messages and future docs**
   - Use "allowlist" terminology going forward

## New Patterns to Add

### High Priority (Common, Safe, Useful)

#### 1. Git Read Operations
```rust
Regex::new(r"^git\s+(log|show|diff|status|branch|tag|ls-files|ls-remote|rev-parse|describe|blame)\b").unwrap(),
```

#### 2. Package Manager Queries
```rust
// npm
Regex::new(r"^npm\s+(list|ls|view|show|search|outdated|audit)\b").unwrap(),

// pip
Regex::new(r"^pip\s+(list|show|search|check)\b").unwrap(),

// cargo
Regex::new(r"^cargo\s+(search|tree|metadata|check)\b").unwrap(),
```

#### 3. Cloud CLI Read Operations
```rust
// AWS describe/get/list operations
Regex::new(r"^aws\s+\w+\s+(describe-|get-|list-)").unwrap(),

// gcloud list/describe/show
Regex::new(r"^gcloud\s+\w+\s+(list|describe|get|show)\b").unwrap(),

// Azure list/show
Regex::new(r"^az\s+\w+\s+(list|show)\b").unwrap(),
```

#### 4. Docker/Container Read Operations
```rust
Regex::new(r"^docker\s+(ps|images|inspect|logs|stats|top|history|version|info)\b").unwrap(),
Regex::new(r"^kubectl\s+(get|describe|logs|top|explain|version|api-resources)\b").unwrap(),
```

#### 5. Data Query Tools (Always Safe)
```rust
Regex::new(r"^(jq|yq|fx|dasel)\s+").unwrap(),  // All operations safe
```

#### 6. System Monitoring (Always Safe)
```rust
Regex::new(r"^(top|htop|ps|df|du|free|vmstat|iostat|uptime|lsof)\s*").unwrap(),
```

#### 7. Text Viewing (Safe Without Redirection)
```rust
Regex::new(r"^(cat|head|tail|less|more|grep|wc|diff)\s+(?!>)").unwrap(),
```

#### 8. File System Info (Read-Only)
```rust
Regex::new(r"^(ls|file|stat|tree|pwd|find)\s+(?!.*-exec.*(rm|mv))").unwrap(),
```

#### 9. Network Tools (Read-Only)
```rust
Regex::new(r"^(ping|dig|nslookup|traceroute|netstat|ss)\s+").unwrap(),
```

### Medium Priority (Less Common but Safe)

```rust
// Terraform read operations
Regex::new(r"^terraform\s+(show|plan|validate|state\s+(list|show)|output)\b").unwrap(),

// Helm read operations  
Regex::new(r"^helm\s+(list|ls|status|get|show|search|template)\b").unwrap(),

// Database read queries
Regex::new(r"^(psql|mysql)\s+.*-c\s+['\"]SELECT\s+").unwrap(),
Regex::new(r"^redis-cli\s+(GET|KEYS|SCAN|INFO)\s+").unwrap(),

// SVN/Mercurial
Regex::new(r"^(hg|svn)\s+(log|status|diff)\b").unwrap(),
```

## Implementation Steps

### Phase 1: Terminology Update

1. **Update src/security/mod.rs**
   ```rust
   //! ## Validation Strategy
   //!
   //! The module uses a two-tier validation approach:
   //!
   //! 1. **Allowlist Check**: Commands matching safe patterns bypass path validation
   //!    - API commands (gh api, kubectl get /apis, argocd app, etc.)
   ```

2. **Update docs/security.md**
   - Replace all instances of "whitelist" with "allowlist"
   - Update headings: "Safe Command Allowlist"
   - Update: "Adding New Allowlist Patterns"

3. **Update test names**
   ```rust
   #[test]
   fn test_github_api_commands_in_allowlist() { ... }
   
   #[test]
   fn test_kubectl_api_commands_in_allowlist() { ... }
   ```

### Phase 2: Add High Priority Patterns

1. **Update `get_safe_command_patterns()`**
   - Add git, npm, docker, kubectl read operations
   - Add data query tools (jq, yq, fx)
   - Add system monitoring tools
   - Organize by category with clear comments

2. **Add tests for each new pattern**
   ```rust
   #[test]
   fn test_git_read_operations_in_allowlist() {
       assert!(validate_path_safety("git log --oneline", &sandbox).is_ok());
       assert!(validate_path_safety("git status", &sandbox).is_ok());
       assert!(validate_path_safety("git diff main", &sandbox).is_ok());
   }
   ```

3. **Update documentation**
   - Add new patterns to docs/security.md
   - Include examples for each category
   - Document pattern structure

### Phase 3: Add Medium Priority Patterns

1. **Conditional addition based on usage**
   - Review tool usage patterns from nu-mcp tools
   - Add terraform/helm if commonly used
   - Add database patterns if needed

2. **Document edge cases**
   - Commands that need special flags (--dry-run, --no-commit)
   - Tools that are mostly safe (sed without -i, find without -exec rm)

## Testing Strategy

### Test Categories

1. **Terminology Tests** - Verify no "whitelist" references remain
2. **Pattern Tests** - Each new pattern has dedicated test
3. **Integration Tests** - Ensure existing tests still pass
4. **Edge Case Tests** - Commands that should still be blocked

### Example Test Structure

```rust
#[test]
fn test_git_operations_in_allowlist() {
    let sandbox = current_dir().unwrap();
    
    // Allowed: read operations
    assert!(validate_path_safety("git log", &sandbox).is_ok());
    assert!(validate_path_safety("git status", &sandbox).is_ok());
    assert!(validate_path_safety("git diff HEAD", &sandbox).is_ok());
    assert!(validate_path_safety("git show abc123", &sandbox).is_ok());
    
    // Still validated: operations that could access files
    // (git clone <path> would check if path is outside sandbox)
}

#[test]
fn test_monitoring_tools_in_allowlist() {
    let sandbox = current_dir().unwrap();
    
    // All monitoring tools are read-only
    assert!(validate_path_safety("top -n 1", &sandbox).is_ok());
    assert!(validate_path_safety("ps aux", &sandbox).is_ok());
    assert!(validate_path_safety("df -h", &sandbox).is_ok());
    assert!(validate_path_safety("free -m", &sandbox).is_ok());
}
```

## Documentation Updates

### docs/security.md Additions

```markdown
## Safe Command Allowlist

Commands in the allowlist bypass filesystem path validation because they use path-like arguments that are NOT filesystem paths, or they are inherently read-only operations.

### Categories

#### 1. API Endpoint Commands
- **GitHub CLI**: `gh api <endpoint>`
- **kubectl**: `kubectl <verb> /api*` 
- **ArgoCD**: `argocd app <cmd> /argocd/*`

#### 2. Read-Only Git Operations  
- Commands: `git log`, `git status`, `git diff`, `git show`, etc.
- These operations only read git history and don't modify files

#### 3. Package Manager Queries
- **npm**: `npm list`, `npm view`, `npm search`, etc.
- **pip**: `pip list`, `pip show`, `pip search`
- **cargo**: `cargo search`, `cargo tree`, `cargo metadata`

#### 4. System Monitoring Tools
- All operations safe: `top`, `htop`, `ps`, `df`, `du`, `free`, etc.
- These tools only display system information

#### 5. Data Query Tools
- All operations safe: `jq`, `yq`, `fx`, `dasel`
- These tools only transform and display data

#### 6. Container Inspection
- **docker**: `docker ps`, `docker images`, `docker inspect`, etc.
- **kubectl**: `kubectl get`, `kubectl describe`, `kubectl logs`, etc.

### Adding Patterns

To add a new safe pattern:

1. Identify the tool and its read-only operations
2. Create a regex pattern that matches the command structure
3. Add to `get_safe_command_patterns()` in `src/security/mod.rs`
4. Add tests in `src/security/mod_test.rs`
5. Document in this file with examples
```

## Migration Checklist

- [ ] Update all "whitelist" → "allowlist" in code
- [ ] Update all "blacklist" → "denylist" in code
- [ ] Update test names and messages
- [ ] Add git read operations
- [ ] Add package manager queries
- [ ] Add system monitoring tools
- [ ] Add data query tools
- [ ] Add container inspection commands
- [ ] Add cloud CLI patterns
- [ ] Update docs/security.md
- [ ] Add comprehensive tests
- [ ] Update readonly-cli-tools.json reference in docs
- [ ] Run all tests
- [ ] Update commit messages to use new terminology

## Benefits

1. **Inclusive Language**: Using "allowlist" is more inclusive and modern
2. **Expanded Coverage**: Support for 50+ common read-only CLI tools
3. **Better DX**: Fewer false positives for legitimate operations
4. **Maintainable**: Patterns organized by category with clear comments
5. **Well-Documented**: Each category explained with examples

## Future Enhancements

1. **Pattern Categories**: Group patterns by type for easier management
2. **Configuration**: Allow users to add custom patterns via config file
3. **Pattern Testing**: Tool to test if a command matches any pattern
4. **Auto-generation**: Generate patterns from readonly-cli-tools.json

---

**Status**: Planning (Not Implemented)  
**Created**: 2025-01-22  
**Dependencies**: readonly-cli-tools.json research completed
