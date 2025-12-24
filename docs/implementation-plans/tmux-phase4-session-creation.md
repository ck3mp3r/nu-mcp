# Tmux Phase 4: Session Creation

## Overview
- **Purpose**: Add `create_session` tool to enable MCP-managed tmux session creation with ownership tracking
- **Target Users**: Developers who want AI-assisted creation of complete tmux workspaces from scratch
- **External Dependencies**: tmux (CLI tool, already used by existing tmux tools)

## Problem Statement

Currently, the tmux MCP tool can:
- ✅ Create windows (in existing sessions)
- ✅ Split panes (in existing windows)
- ✅ Kill sessions (but only MCP-created ones)

**Gap:** Cannot create sessions via MCP, which means:
1. Users must manually create sessions before MCP can manage them
2. The `kill_session` tool cannot be fully tested/used (requires MCP-created sessions)
3. Cannot create complete tmux workspaces from scratch via AI

**Solution:** Add `create_session` tool that:
- Creates new tmux sessions with configurable options
- Automatically marks session as MCP-created (using `@mcp_tmux` user option)
- Enables full lifecycle management (create → use → destroy)

## Capabilities

### Tool: create_session

**Description:**
Create a new tmux session with optional configuration. The session will be marked with `@mcp_tmux` ownership marker, allowing it to be safely destroyed later with `kill_session`.

**Parameters:**
- `name` (required): Session name
- `window_name` (optional): Name for the initial window (default: tmux default)
- `directory` (optional): Starting directory for the session (default: current directory)
- `detached` (optional): Create detached session (default: `true` - don't switch to it)

**Returns:**
```json
{
  "success": true,
  "session_id": "$session_id",
  "session_name": "my-session",
  "initial_window": "@window_id",
  "message": "Created session 'my-session' (detached)"
}
```

**Safety:**
- Session is marked with `@mcp_tmux` user option on creation
- Can be destroyed later with `kill_session` (with force flag)
- User sessions remain protected

**JSON Schema:**
```json
{
  "name": "create_session",
  "description": "Create a new tmux session with ownership tracking. The session will be marked as MCP-created, allowing safe destruction later with kill_session. By default, creates a detached session (does not switch focus).",
  "input_schema": {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "description": "Name for the new session (required). Must be unique across all tmux sessions."
      },
      "window_name": {
        "type": "string",
        "description": "Name for the initial window (optional, defaults to tmux default)"
      },
      "directory": {
        "type": "string",
        "description": "Starting directory for the session (optional, defaults to current directory)"
      },
      "detached": {
        "type": "boolean",
        "description": "Create session in detached mode (optional, default: true). If false, switches to the new session."
      }
    },
    "required": ["name"]
  }
}
```

## Implementation Strategy

### Module: workload.nu (extend existing)

Add new function following existing patterns:

```nushell
# Create a new tmux session with MCP ownership marker
#
# Creates a detached session by default to avoid disrupting user's current work.
# Automatically marks the session with @mcp_tmux user option for safe lifecycle management.
export def create-session [
    name: string              # Session name (must be unique)
    --window-name: string     # Optional: Name for initial window
    --directory: string       # Optional: Starting directory
    --detached: bool = true   # Optional: Create detached (default: true)
] {
    # Check if session already exists
    let existing = (list-sessions | where session == $name)
    if ($existing | length) > 0 {
        return {
            success: false
            error: "SessionExists"
            message: $"Session '($name)' already exists"
        }
    }
    
    # Build tmux command
    mut cmd_args = ['new-session']
    
    # Session name
    $cmd_args = ($cmd_args | append ['-s' $name])
    
    # Detached or attached
    if $detached {
        $cmd_args = ($cmd_args | append '-d')
    }
    
    # Initial window name
    if $window_name != null {
        $cmd_args = ($cmd_args | append ['-n' $window_name])
    }
    
    # Starting directory
    if $directory != null {
        $cmd_args = ($cmd_args | append ['-c' $directory])
    }
    
    # Create the session
    try {
        exec_tmux_command $cmd_args
        
        # Mark session as MCP-created (session-level user option)
        exec_tmux_command ['set-option' '-t' $name '@mcp_tmux' 'true']
        
        # Get session info
        let session_info = (exec_tmux_command ['display-message' '-t' $name '-p' '#{session_id}'])
        
        {
            success: true
            session_id: ($session_info | str trim)
            session_name: $name
            message: $"Created session '($name)' \(($detached ? 'detached' : 'attached'))"
        }
    } catch { |err|
        {
            success: false
            error: "CreationFailed"
            message: $"Failed to create session: ($err.msg)"
        }
    }
}
```

### Module: mod.nu (update)

Add to `list-tools`:
```nushell
{
    name: "create_session"
    description: "Create a new tmux session with ownership tracking..."
    input_schema: { ... }
}
```

Add to `call-tool`:
```nushell
"create_session" => {
    let name = $parsed_args | get name
    let window_name = if "window_name" in $parsed_args { 
        $parsed_args | get window_name 
    } else { 
        null 
    }
    let directory = if "directory" in $parsed_args { 
        $parsed_args | get directory 
    } else { 
        null 
    }
    let detached = if "detached" in $parsed_args { 
        $parsed_args | get detached 
    } else { 
        true 
    }
    
    create-session $name --window-name $window_name --directory $directory --detached $detached
    | to json
}
```

## Testing Strategy

### Unit Tests (test_workload.nu)

```nushell
# Test: create-session with just name
export def "test create-session with name only" [] {
    use nu-mimic *
    
    let result = with-mocks [
        # Mock: new-session command
        { cmd: "tmux", exit_code: 0, stdout: "", args_pattern: "new-session -s test-session -d" }
        # Mock: set-option command (marking)
        { cmd: "tmux", exit_code: 0, stdout: "", args_pattern: "set-option -t test-session @mcp_tmux true" }
        # Mock: display-message (get session ID)
        { cmd: "tmux", exit_code: 0, stdout: "$1\n", args_pattern: "display-message -t test-session" }
    ] {
        create-session "test-session"
    }
    
    assert ($result.success == true)
    assert ($result.session_name == "test-session")
    assert ($result.message | str contains "detached")
}

# Test: create-session with all options
export def "test create-session with all options" [] {
    use nu-mimic *
    
    let result = with-mocks [
        { cmd: "tmux", exit_code: 0, stdout: "", args_pattern: "new-session -s work -n code -c /tmp" }
        { cmd: "tmux", exit_code: 0, stdout: "", args_pattern: "set-option -t work @mcp_tmux true" }
        { cmd: "tmux", exit_code: 0, stdout: "$2\n", args_pattern: "display-message" }
    ] {
        create-session "work" --window-name "code" --directory "/tmp" --detached false
    }
    
    assert ($result.success == true)
    assert ($result.session_name == "work")
}

# Test: create-session detects duplicate
export def "test create-session rejects duplicate name" [] {
    use nu-mimic *
    
    # Mock list-sessions to return existing session
    let result = with-mocks [
        { cmd: "tmux", exit_code: 0, stdout: "existing-session\n", args_pattern: "list-sessions" }
    ] {
        create-session "existing-session"
    }
    
    assert ($result.success == false)
    assert ($result.error == "SessionExists")
}

# Test: create-session sets mcp marker
export def "test create-session sets mcp marker" [] {
    use nu-mimic *
    
    let mocks = [
        { cmd: "tmux", exit_code: 0, stdout: "", args_pattern: "new-session -s marked -d" }
        { cmd: "tmux", exit_code: 0, stdout: "", args_pattern: "set-option -t marked @mcp_tmux true" }
        { cmd: "tmux", exit_code: 0, stdout: "$3\n", args_pattern: "display-message" }
    ]
    
    let result = with-mocks $mocks {
        create-session "marked"
    }
    
    # Verify set-option was called with correct arguments
    assert ($result.success == true)
}
```

### Integration Tests (test_integration.nu)

```nushell
# Test: create and kill session lifecycle
export def "test session lifecycle with mcp ownership" [] {
    # Generate unique session name
    let session_name = $"mcp-lifecycle-test-(date now | format date '%Y%m%d-%H%M%S')"
    
    try {
        # Create session via MCP
        let create_result = (create-session $session_name)
        assert ($create_result.success == true)
        
        # Verify session exists and has marker
        let marker_check = (check-mcp-ownership $session_name "session")
        assert ($marker_check.owned == true)
        
        # Kill session via MCP (should succeed)
        let kill_result = (kill-session $session_name --force)
        assert ($kill_result.success == true)
        
        # Verify session is gone
        let sessions = (list-sessions | where session == $session_name)
        assert (($sessions | length) == 0)
    } catch { |err|
        # Cleanup on error
        try { ^tmux kill-session -t $session_name } catch { }
        error make { msg: $"Test failed: ($err.msg)" }
    }
}
```

## Milestones

### Phase 1: Research & Planning
- [x] Create implementation plan
- [ ] Research tmux `new-session` command options
- [ ] Research session-level user options vs window/pane markers
- [ ] Document command format and flags

### Phase 2: Implementation
- [ ] Implement `create-session` function in `workload.nu`
- [ ] Add duplicate session name checking
- [ ] Add session marking with `@mcp_tmux` user option
- [ ] Handle optional parameters (window_name, directory, detached)

### Phase 3: MCP Integration
- [ ] Add `create_session` to `list-tools` in `mod.nu`
- [ ] Add `create_session` to `call-tool` routing in `mod.nu`
- [ ] Update README with `create_session` documentation

### Phase 4: Testing
- [ ] Write unit tests for `create-session` function
- [ ] Write integration test for full lifecycle (create → verify marker → kill)
- [ ] Test duplicate name detection
- [ ] Test all parameter combinations
- [ ] Verify marker persistence

### Phase 5: Documentation
- [ ] Update `tools/tmux/README.md` with `create_session` examples
- [ ] Add session creation workflow examples
- [ ] Document complete workspace creation pattern

### Phase 6: Manual Verification
- [ ] Test creating session with just name
- [ ] Test creating session with all options
- [ ] Test creating attached vs detached session
- [ ] Verify `@mcp_tmux` marker is set correctly
- [ ] Verify full lifecycle: create → use → kill

## Success Criteria

- [ ] `create_session` tool successfully creates tmux sessions
- [ ] Sessions are marked with `@mcp_tmux` user option
- [ ] `kill_session` can destroy MCP-created sessions
- [ ] Duplicate session names are rejected with clear error
- [ ] All parameters (name, window_name, directory, detached) work correctly
- [ ] All tests pass (unit + integration)
- [ ] Manual verification confirms correct behavior
- [ ] Documentation is complete and accurate

## Future Enhancements (Post Phase 4)

- Session templates (create session with predefined window/pane layout)
- Workspace presets (e.g., "dev-workspace" creates session + multiple windows + panes)
- Session cloning (duplicate existing session structure)
- Attach/detach operations for existing sessions

## Related Work

- **Phase 2**: Implemented `create_window` and `split_pane` (ownership tracking established)
- **Phase 3**: Implemented `kill_session`, `kill_window`, `kill_pane` (destruction with safety)
- **Phase 4**: Completes the creation side of lifecycle management

## Dependencies

- tmux >= 2.1 (for user options support)
- Existing tmux tool modules (core.nu, session.nu, workload.nu)
- nu-mimic for testing

## Risk Assessment

**Low Risk:**
- Small, focused addition following existing patterns
- Session creation is non-destructive (won't affect existing sessions)
- Ownership tracking already proven in Phase 2/3
- Comprehensive testing strategy in place

**Potential Issues:**
- Session name conflicts (mitigated by duplicate checking)
- User switching to attached session unexpectedly (mitigated by default detached=true)
- Marker persistence across tmux server restarts (already tested in Phase 3)
