# Security Module - Safe Command Patterns

## Overview

This module implements filesystem path validation for the nu-mcp sandbox. Commands are validated using a two-tier approach:

1. **Allowlist Check**: Commands matching patterns in `safe_command_patterns.txt` bypass path validation
2. **Path Validation**: All other commands undergo full filesystem path checking

## Safe Command Patterns File

### Location
`src/security/safe_command_patterns.txt`

### Format
```
# Comments start with #
# Empty lines are ignored
# One regex pattern per line

# Pattern with explanation
^command\s+subcommand\s+
```

### Loading
- Patterns are loaded at **compile time** using `include_str!`
- The file is embedded in the binary
- Changes require recompilation

### Rules

**ONLY** add commands that use **NON-filesystem path arguments**:

✅ **Safe to add:**
- API endpoints: `gh api /repos/owner/repo`
- Resource identifiers: `kubectl get /apis/apps/v1`
- URLs: `curl https://api.example.com`
- Resource paths: `argocd app get /argocd/myapp`
- System info: `docker ps`, `git status` (no path arguments)
- Data transformers: `jq`, `yq` (operate on stdin/stdout)

❌ **DO NOT add:**
- File readers: `cat`, `less`, `head`, `tail`
- File listers: `ls`, `find`, `tree`
- File info: `stat`, `file`
- Text processors that read files: `grep`, `awk`, `sed`

**Why?** These commands access filesystem paths and MUST be validated against the sandbox.

## Adding New Patterns

### Step 1: Identify the Pattern

Determine if the command uses non-filesystem paths:

```bash
# ✅ Good: API endpoint (not a filesystem path)
gh api /repos/owner/repo/contents/file.yml

# ❌ Bad: Filesystem path (needs validation)
cat /etc/passwd
```

### Step 2: Write the Regex

Patterns should:
- Start with `^` (match from beginning)
- Be specific to avoid over-matching
- Use `\s+` for required whitespace
- Use `\b` for word boundaries

Example:
```
# GitHub CLI - API endpoints only
^gh\s+api\s+
```

### Step 3: Test the Pattern

Test against both valid and invalid commands:

```rust
// In src/security/mod_test.rs
#[test]
fn test_your_pattern_in_allowlist() {
    let sandbox = current_dir().unwrap();
    
    // Should match (bypass validation)
    assert!(validate_path_safety("your-tool api /endpoint", &sandbox).is_ok());
    
    // Should NOT match (still validated)
    assert!(validate_path_safety("your-tool file /etc/passwd", &sandbox).is_err());
}
```

### Step 4: Document the Pattern

Add clear comments in the pattern file:

```
# Tool Name - Purpose
# Matches: command pattern examples
# Notes: Special cases or limitations
^your-pattern\s+
```

## Common Pitfalls

### 1. Too Broad Patterns

❌ **Bad**: Matches everything
```
^git\s+
```

✅ **Good**: Specific to read-only operations
```
^git\s+(log|status|diff|show)\b
```

### 2. Filesystem-Accessing Commands

❌ **Bad**: `cat` reads files, needs validation
```
^cat\s+
```

✅ **Good**: Only non-filesystem operations
```
^git\s+log\s+
```

### 3. Negative Lookahead/Lookbehind

❌ **Bad**: Rust regex doesn't support `(?!...)`
```
^cat\s+(?!>)
```

✅ **Good**: Simple positive matching
```
^http\s+get\s+
```

## Pattern Categories

### API Endpoints
Commands that accept URL-like paths for API access:
- `gh api /repos/...`
- `kubectl get /apis/...`
- `argocd app get /argocd/...`

### HTTP Clients
Commands that fetch URLs (not filesystem paths):
- `curl https://...`
- `wget http://...`
- `http get https://...`

### Read-Only System Info
Commands that never access user-specified paths:
- `git log`, `git status`
- `docker ps`, `docker images`
- `npm list`, `pip show`

### Data Transformers
Commands that operate on stdin/stdout only:
- `jq`
- `yq`
- `fx`
- `dasel`

## Testing

### Unit Tests
Each pattern should have dedicated tests:

```rust
#[test]
fn test_pattern_matches_intended_commands() {
    let sandbox = current_dir().unwrap();
    
    // Test allowlist hits
    assert!(validate_path_safety("safe command", &sandbox).is_ok());
    
    // Test allowlist misses (still validated)
    assert!(validate_path_safety("unsafe /etc/passwd", &sandbox).is_err());
}
```

### Manual Testing
```bash
# Rebuild to load pattern changes
cargo build

# Run specific test
cargo test test_your_pattern

# Run all security tests
cargo test security::
```

## Maintenance

### Regular Review
- Remove patterns for deprecated tools
- Update patterns for tool changes
- Add patterns for new tools as needed

### Performance
- Keep pattern count reasonable (< 100)
- Use specific patterns to minimize regex overhead
- Profile if pattern matching becomes slow

## References

- Pattern file: `src/security/safe_command_patterns.txt`
- Implementation: `src/security/mod.rs`
- Tests: `src/security/mod_test.rs`
- User docs: `docs/security.md`
