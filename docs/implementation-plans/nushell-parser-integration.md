# Nushell Parser Integration for Secure Sandbox Validation

## Overview

This plan outlines the implementation of proper AST-based path validation for the nu-mcp sandbox by integrating Nushell's parser (`nu-parser` and `nu-protocol` crates) directly into the Rust codebase. This approach provides accurate, security-focused validation by understanding command structure at the AST level rather than relying on string pattern matching.

## Problem Statement

The current sandbox validation (`src/security/mod.rs`) uses heuristic string parsing to identify filesystem paths in commands. This approach has fundamental limitations:

1. **Whack-a-mole edge cases**: New command patterns (API paths, tool-specific arguments) continuously break validation
2. **False positives**: API endpoints like `/repos/owner/repo` are incorrectly flagged as filesystem paths
3. **False negatives**: Sophisticated path escapes might bypass string-based detection
4. **Maintenance burden**: Each new tool or pattern requires custom handling logic

**Current approach**: Parse commands as strings → guess which tokens are paths → validate those paths

**Proposed approach**: Parse commands with Nushell's parser → inspect AST → validate only actual file path arguments

## Goals

1. **Accurate path detection**: Use AST structure to identify genuine filesystem path arguments
2. **Eliminate false positives**: API paths, quoted strings, and non-path arguments are correctly ignored
3. **Security-first**: Default deny unknown patterns; only allow validated path arguments
4. **Maintainable**: Leverage Nushell's maintained parser instead of custom parsing logic
5. **Performance**: Minimize parsing overhead for command validation

## Non-Goals

- **Command execution validation**: This is only about pre-execution path safety checks
- **Nushell version independence**: We will couple to specific Nushell parser versions (acceptable tradeoff)
- **Zero dependencies**: Adding `nu-parser` and `nu-protocol` is acceptable for security

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────┐
│                    MCP Router                           │
│                (src/mcp/router.rs)                      │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ validate_command()
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              AstPathValidator                           │
│           (src/security/ast_validator.rs)               │
│                                                          │
│  ┌────────────────────────────────────────────┐        │
│  │ 1. Parse command → AST                     │        │
│  │    (nu_parser::parse)                      │        │
│  └────────────────────────────────────────────┘        │
│                       │                                  │
│                       ▼                                  │
│  ┌────────────────────────────────────────────┐        │
│  │ 2. Traverse AST                            │        │
│  │    (find Expression::Filepath nodes)       │        │
│  └────────────────────────────────────────────┘        │
│                       │                                  │
│                       ▼                                  │
│  ┌────────────────────────────────────────────┐        │
│  │ 3. Extract path literals                   │        │
│  │    (get actual path strings)               │        │
│  └────────────────────────────────────────────┘        │
│                       │                                  │
│                       ▼                                  │
│  ┌────────────────────────────────────────────┐        │
│  │ 4. Validate paths against sandbox          │        │
│  │    (canonicalize & check bounds)           │        │
│  └────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────┘
                       │
                       │ Result<(), String>
                       ▼
               Command Execution
```

### Key Dependencies

```toml
[dependencies]
# Existing dependencies remain...

# New: Nushell parser integration
nu-parser = "0.98"      # Parser for Nushell commands
nu-protocol = "0.98"    # AST definitions and protocol types
nu-engine = "0.98"      # Engine state management (optional, for context)
```

**Version pinning strategy**: Pin to specific Nushell versions in lockstep with the `nu` binary we execute. Update dependencies when upgrading Nushell runtime.

### AST Node Types of Interest

From `nu-protocol::ast`, we care about:

1. **`Expression::Filepath`**: Literal path expressions
2. **`Expression::GlobPattern`**: Glob patterns (may contain paths)
3. **`Expression::String`**: String literals (usually NOT paths unless in specific contexts)
4. **`PathMember`**: Members of path expressions (e.g., `$env.HOME`)
5. **`Call` arguments**: Positional and named arguments to commands

**Critical distinction**: 
- `Expression::Filepath("/etc/passwd")` → **VALIDATE**
- `Expression::String("/repos/owner/file")` → **IGNORE** (it's a string literal, not a file path)

### Module Structure

```
src/security/
├── mod.rs                    # Current string-based validation (deprecated)
├── ast_validator.rs          # NEW: AST-based path validation
├── path_checker.rs           # NEW: Path sandbox boundary checking (extracted from mod.rs)
└── mod_test.rs               # Updated tests
```

## Implementation Phases

### Phase 1: Dependency Integration and Basic Parsing

**Milestone 1.1: Add Dependencies**
- [x] Research Nushell parser API via Context7
- [ ] Add `nu-parser`, `nu-protocol` to `Cargo.toml`
- [ ] Verify builds successfully
- [ ] Document version pinning strategy

**Milestone 1.2: Create AST Parsing Infrastructure**
- [ ] Create `src/security/ast_validator.rs`
- [ ] Implement `parse_command(command: &str) -> Result<Block, ParseError>`
- [ ] Initialize `EngineState` and `StateWorkingSet` for parsing context
- [ ] Write basic test: parse simple command and verify AST structure

**Test cases**:
```rust
#[test]
fn test_parse_simple_command() {
    let ast = parse_command("ls /etc").unwrap();
    assert!(/* AST contains ls command with /etc argument */);
}

#[test]
fn test_parse_pipeline() {
    let ast = parse_command("ls | where name == 'test'").unwrap();
    assert!(/* AST contains pipeline with 2 commands */);
}

#[test]
fn test_parse_error_handling() {
    let result = parse_command("invalid ((( syntax");
    assert!(result.is_err());
}
```

### Phase 2: AST Traversal and Path Extraction

**Milestone 2.1: Implement AST Visitor Pattern**
- [ ] Create `PathExpressionVisitor` struct
- [ ] Implement `Traverse` trait for visiting AST nodes
- [ ] Collect all `Expression::Filepath` and `Expression::GlobPattern` nodes
- [ ] Write tests for AST traversal

**Milestone 2.2: Extract Path Literals**
- [ ] Convert `Expression` nodes to actual path strings
- [ ] Handle variable expansion (e.g., `$env.HOME/file` → actual home path)
- [ ] Handle glob patterns (e.g., `*.txt` → relative to sandbox)
- [ ] Write tests for path extraction

**Test cases**:
```rust
#[test]
fn test_extract_simple_paths() {
    let paths = extract_paths("ls /etc /var/log").unwrap();
    assert_eq!(paths, vec!["/etc", "/var/log"]);
}

#[test]
fn test_ignore_string_literals() {
    let paths = extract_paths(r#"gh api "/repos/owner/repo""#).unwrap();
    assert_eq!(paths, vec![]); // Quoted string, not a file path
}

#[test]
fn test_extract_glob_patterns() {
    let paths = extract_paths("ls *.txt").unwrap();
    assert!(paths.contains(&"*.txt"));
}

#[test]
fn test_variable_expansion() {
    // This may require engine state to resolve variables
    let paths = extract_paths("ls $env.HOME/file.txt").unwrap();
    assert!(paths[0].contains("file.txt"));
}
```

### Phase 3: Path Validation Against Sandbox

**Milestone 3.1: Refactor Path Checking Logic**
- [ ] Extract path validation logic from `src/security/mod.rs` to `src/security/path_checker.rs`
- [ ] Create `validate_path_in_sandbox(path: &Path, sandbox: &Path) -> Result<(), String>`
- [ ] Keep existing canonicalization and boundary checking logic
- [ ] Write focused unit tests for path validation

**Milestone 3.2: Integrate AST Validation into Router**
- [ ] Create `validate_command_ast(command: &str, sandbox_dir: &Path) -> Result<(), String>`
- [ ] Parse command → extract paths → validate each path
- [ ] Replace call to `validate_path_safety()` in `src/mcp/router.rs` with new function
- [ ] Add feature flag or config option to toggle AST vs. string validation

**Test cases**:
```rust
#[test]
fn test_validate_paths_in_sandbox() {
    let sandbox = Path::new("/tmp/sandbox");
    
    // Allowed: paths within sandbox
    assert!(validate_command_ast("ls /tmp/sandbox/file.txt", sandbox).is_ok());
    
    // Blocked: paths outside sandbox
    assert!(validate_command_ast("ls /etc/passwd", sandbox).is_err());
    
    // Allowed: relative paths (resolve to sandbox)
    assert!(validate_command_ast("ls ./file.txt", sandbox).is_ok());
}

#[test]
fn test_validate_api_paths_ignored() {
    let sandbox = Path::new("/tmp/sandbox");
    
    // String literals with /slashes should be ignored (not treated as file paths)
    assert!(validate_command_ast(r#"gh api "/repos/owner/repo""#, sandbox).is_ok());
}

#[test]
fn test_validate_path_traversal() {
    let sandbox = Path::new("/tmp/sandbox");
    
    // Blocked: traversal escapes sandbox
    assert!(validate_command_ast("ls ../../../etc/passwd", sandbox).is_err());
    
    // Allowed: traversal stays in sandbox
    assert!(validate_command_ast("ls subdir/../file.txt", sandbox).is_ok());
}
```

### Phase 4: Edge Cases and Optimization

**Milestone 4.1: Handle Special Cases**
- [ ] Commands with no file path arguments (e.g., `gh api /endpoint`)
- [ ] Commands with mixed path types (literal paths + glob patterns)
- [ ] Subexpressions and command substitution (e.g., `ls (which nu)`)
- [ ] Piped commands (validate each pipeline element)
- [ ] Home directory expansion (`~/file.txt`)

**Milestone 4.2: Performance Optimization**
- [ ] Benchmark parsing overhead vs. string-based validation
- [ ] Consider caching `EngineState` initialization
- [ ] Profile AST traversal for large commands
- [ ] Document performance characteristics

**Test cases**:
```rust
#[test]
fn test_no_path_arguments() {
    let sandbox = Path::new("/tmp/sandbox");
    
    // Commands with no file paths should pass validation
    assert!(validate_command_ast("echo 'hello'", sandbox).is_ok());
    assert!(validate_command_ast("gh api /repos/owner/repo", sandbox).is_ok());
}

#[test]
fn test_pipeline_validation() {
    let sandbox = Path::new("/tmp/sandbox");
    
    // Each pipeline element should be validated
    assert!(validate_command_ast("cat /etc/passwd | grep root", sandbox).is_err());
    assert!(validate_command_ast("ls sandbox/file.txt | sort", sandbox).is_ok());
}

#[test]
fn test_subexpression_paths() {
    let sandbox = Path::new("/tmp/sandbox");
    
    // Paths in subexpressions should be validated
    assert!(validate_command_ast("cat (which nu)", sandbox).is_err()); // 'which' returns paths outside sandbox
}

#[test]
fn benchmark_parsing_overhead() {
    // Measure parsing time for typical commands
    let iterations = 1000;
    let start = Instant::now();
    
    for _ in 0..iterations {
        let _ = parse_command("ls /tmp/file.txt | where size > 100");
    }
    
    let elapsed = start.elapsed();
    println!("Average parse time: {:?}", elapsed / iterations);
    
    // Assert reasonable performance (e.g., < 1ms per command)
    assert!(elapsed < Duration::from_millis(iterations as u64));
}
```

### Phase 5: Documentation and Migration

**Milestone 5.1: Documentation**
- [ ] Document AST validation approach in `docs/security.md`
- [ ] Add inline comments explaining AST node types
- [ ] Create architecture diagram showing validation flow
- [ ] Write migration guide from string-based to AST-based validation

**Milestone 5.2: Feature Flag and Rollout**
- [ ] Add `--validation-mode` CLI flag: `string` (legacy) or `ast` (new)
- [ ] Default to `ast` mode
- [ ] Deprecation notice for `string` mode
- [ ] Plan to remove string-based validation in future version

**Milestone 5.3: Integration Testing**
- [ ] Test with real-world commands from existing tool catalog
- [ ] Verify `gh`, `kubectl`, `argocd`, `curl` commands work correctly
- [ ] Test edge cases from GitHub issues / user reports
- [ ] Performance testing under load

## Technical Challenges and Solutions

### Challenge 1: Nushell Version Coupling

**Problem**: Nushell's parser API may change between versions, requiring updates to our code.

**Solution**:
- Pin to specific Nushell versions in `Cargo.toml`
- Document which Nushell versions are supported
- CI tests against multiple Nushell versions
- Version compatibility matrix in README

### Challenge 2: Parser Initialization Overhead

**Problem**: Creating `EngineState` and `StateWorkingSet` for every command may be slow.

**Solution**:
- Profile actual overhead (likely negligible for single commands)
- Consider lazy static initialization of `EngineState` (shared across validations)
- Cache parser state if overhead is significant
- Benchmark: target < 1ms per command parse

### Challenge 3: Variable Expansion

**Problem**: Paths like `$env.HOME/file.txt` require runtime context to resolve.

**Solution**:
- Use `EngineState` to evaluate variable expressions
- For sandbox validation, evaluate variables in minimal context
- Handle missing variables gracefully (conservative: deny if can't resolve)
- Document which variables are supported for path expansion

### Challenge 4: Command Substitution

**Problem**: Commands like `cat (which nu)` embed subcommands that return paths.

**Solution**:
- Recursively validate subexpressions
- Traverse entire AST, not just top-level arguments
- Handle `Expression::Subexpression` and `Expression::Block` nodes
- Conservative approach: if subexpression can't be statically validated, deny

### Challenge 5: Glob Pattern Validation

**Problem**: Glob patterns like `*.txt` need special handling—they're paths but not fully specified.

**Solution**:
- Treat globs as relative to sandbox directory
- Validate that glob pattern base directory is within sandbox
- Example: `../../../*.txt` is blocked, `subdir/*.txt` is allowed
- Use glob expansion (if needed) to resolve actual files

## Security Considerations

### Threat Model

**What we protect against**:
1. **Path traversal attacks**: Commands attempting to access files outside sandbox via `..` or absolute paths
2. **Symbolic link attacks**: Following symlinks that escape sandbox
3. **Home directory escapes**: Accessing `~/` paths outside sandbox

**What we do NOT protect against** (out of scope):
1. **Command injection**: Malicious command execution (Nushell's responsibility)
2. **Resource exhaustion**: Commands that consume excessive CPU/memory
3. **Network access**: Commands that make external network requests

### Validation Rules

**Allow**:
- Relative paths that resolve within sandbox
- Absolute paths that are within sandbox
- Glob patterns that start within sandbox
- String literals (not file paths)

**Deny**:
- Absolute paths outside sandbox
- Relative paths that traverse outside sandbox (e.g., `../../../etc/passwd`)
- Unresolvable variable expansions (conservative: deny unknown)
- Paths that canonicalize outside sandbox (follows symlinks)

### Fallback Behavior

**If AST parsing fails**:
- Option A: Deny command (conservative, secure)
- Option B: Fall back to string-based validation (permissive, less secure)
- **Recommended**: Option A with clear error message

**If path extraction fails**:
- Log warning
- Deny command
- User can file issue for unsupported command pattern

## Testing Strategy

### Unit Tests

- **Parser module**: Test AST parsing for various command structures
- **Traversal module**: Test path extraction from AST nodes
- **Validation module**: Test sandbox boundary checking
- **Integration**: Test full validation pipeline

### Integration Tests

- **Real commands**: Test with actual tool commands (`gh`, `kubectl`, `argocd`, etc.)
- **Edge cases**: Test from existing GitHub issues and bug reports
- **Performance**: Benchmark against string-based validation

### Security Tests

- **Path traversal**: Attempt to escape sandbox via various methods
- **Symbolic links**: Test with symlinks inside and outside sandbox
- **Variable expansion**: Test `$env.*` variables for path escapes
- **Subcommands**: Test nested command execution

### Regression Tests

- **Convert existing tests**: Migrate `src/security/mod_test.rs` to use AST validation
- **Maintain test coverage**: Ensure all existing scenarios still pass
- **Add new tests**: Cover AST-specific edge cases

## Performance Targets

- **Parse time**: < 1ms per command (99th percentile)
- **Validation time**: < 5ms total per command
- **Memory overhead**: < 1MB per validation (temporary allocations)
- **Startup time**: No noticeable impact on MCP server startup

## Rollout Plan

### Phase 1: Development (Weeks 1-2)
- Implement basic AST parsing and path extraction
- Write core unit tests
- Benchmark performance

### Phase 2: Integration (Week 3)
- Integrate into MCP router with feature flag
- Add integration tests with real commands
- Document new validation approach

### Phase 3: Testing (Week 4)
- Enable in CI/CD pipeline
- Test with existing tool catalog
- Gather performance metrics

### Phase 4: Rollout (Week 5)
- Enable AST validation by default
- Keep string-based validation as fallback
- Monitor for issues

### Phase 5: Deprecation (Week 6+)
- Announce deprecation of string-based validation
- Remove string-based code in next major version
- Update documentation

## Open Questions

1. **How to handle dynamic paths?** (e.g., paths constructed at runtime from user input)
   - Conservative: deny if path can't be statically determined
   - Permissive: allow with warning
   - **Decision needed**: Lean toward conservative for security

2. **Should we validate paths in quoted strings?**
   - Current answer: No, string literals are not file paths
   - Edge case: Some tools accept file paths as strings (rare)
   - **Decision needed**: Document this limitation, require users to file issues

3. **How to handle plugin/custom commands?**
   - Nushell plugins have their own command signatures
   - May need to parse plugin manifests to understand arguments
   - **Decision needed**: Start with built-in commands only, expand later

4. **Performance vs. security tradeoff?**
   - AST parsing has overhead, string checking is faster
   - Security is more important than speed
   - **Decision**: Prioritize security, optimize if benchmarks show issues

## Success Criteria

- [ ] Zero false positives for API endpoints (e.g., `gh api /repos/...`)
- [ ] Zero false negatives for path traversal attacks
- [ ] Parse time < 1ms for 99% of commands
- [ ] All existing security tests pass
- [ ] 90%+ code coverage for new validation module
- [ ] Positive user feedback (no complaints about broken commands)

## References

- [Nushell Parser Documentation](https://docs.rs/nu-parser)
- [Nushell Protocol Documentation](https://docs.rs/nu-protocol)
- [Nushell Book - Parser](https://www.nushell.sh/book/)
- [MCP Security Guide](docs/security.md)
- [Current Sandbox Implementation](src/security/mod.rs)

## Future Enhancements

Beyond initial implementation:

1. **Semantic analysis**: Understand command intent (read vs. write operations)
2. **Permission levels**: Different validation rules for read-only vs. destructive commands
3. **Custom parsers**: Support non-Nushell commands (bash, PowerShell) via pluggable parsers
4. **Machine learning**: Learn from user corrections to improve validation heuristics
5. **Interactive mode**: Prompt user for confirmation on ambiguous paths

---

**Document Version**: 1.0  
**Created**: 2025-01-22  
**Author**: AI Agent with Human Review  
**Status**: Planning (Not Implemented)
