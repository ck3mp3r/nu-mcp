# Tmux Window & Pane Management Implementation Plan

## Overview
- **Purpose**: Enable AI assistants to create new tmux windows and split panes, facilitating automated workspace setup and task organization
- **Target Users**: Developers using tmux who want AI-assisted workspace management
- **External Dependencies**: tmux (CLI tool, already used by existing tmux tools)

## Capabilities
- [x] Research tmux new-window and split-window commands
- [ ] `create_window`: Create new window in a tmux session
  - Required: session name
  - Optional: window name, working directory, target window index
- [ ] `split_pane`: Split a pane horizontally or vertically
  - Required: session name, direction (horizontal/vertical)
  - Optional: window name/ID, pane ID, working directory, size percentage

## Module Structure
- `mod.nu`: MCP interface and routing (update with new tools)
- `core.nu`: Low-level tmux command execution (already exists, reuse `exec_tmux_command`)
- `workload.nu`: **NEW** - Window and pane creation/management operations
- `formatters.nu`: Response formatting (may need updates for new operations)
- `tests/test_workload.nu`: **NEW** - Tests for window/pane management
- `tests/wrappers.nu`: Mock support (already exists, works for new tests)

## Context7 Research
- [x] Research tmux new-window command: `tmux new-window` (neww)
  - Flags: `-d` (don't switch), `-n <name>`, `-c <directory>`, `-t <target>`
- [x] Research tmux split-window command: `tmux split-window` (splitw)
  - Flags: `-h` (horizontal), `-v` (vertical), `-c <directory>`, `-t <target>`, `-p <percentage>`, `-d` (don't switch)
- [x] Research pane_current_path for inheriting directory
- [x] Research format variables: `#{pane_id}`, `#{window_id}`, `#{window_index}`

## Security Considerations
- **Safety mode**: Not applicable (creating windows/panes is non-destructive)
- **Sensitive data**: No sensitive data involved
- **Rate limiting**: Not needed (local tmux commands)
- **Validation**: Ensure session exists before operations

## TDD Milestones (Red-Green-Refactor)

### Setup
- [x] Research tmux commands
- [ ] Create implementation plan
- [ ] Create feature branch: `feature/tmux-window-pane-tools`

### create_window Tool (Red-Green-Refactor cycles)
- [ ] **RED**: Write failing test for create_window with session-only targeting
  - Test: Creates window in session, returns window info
- [ ] **GREEN**: Implement basic create_window functionality to pass test
  - Add to workload.nu: `create-window` function
  - Call `exec_tmux_command` with appropriate args
- [ ] **RED**: Write failing test for create_window with optional window name
  - Test: Creates window with custom name
- [ ] **GREEN**: Add window name support (`-n` flag)
- [ ] **RED**: Write failing test for create_window with optional working directory
  - Test: Creates window with specific working directory
- [ ] **GREEN**: Add working directory support (`-c` flag)

### split_pane Tool (Red-Green-Refactor cycles)
- [ ] **RED**: Write failing test for split_pane horizontal split
  - Test: Splits pane horizontally, returns new pane info
- [ ] **GREEN**: Implement basic split_pane with horizontal support
  - Add to workload.nu: `split-pane` function
  - Default to horizontal split (`-h` flag)
- [ ] **RED**: Write failing test for split_pane vertical split
  - Test: Splits pane vertically with `-v` flag
- [ ] **GREEN**: Add vertical split support (direction parameter)
- [ ] **RED**: Write failing test for split_pane with working directory
  - Test: Split with custom working directory
- [ ] **GREEN**: Add working directory support (`-c` flag)

### Integration & Polish
- [ ] Add create_window and split_pane to mod.nu tool schema
  - Define JSON schemas with proper descriptions
  - Add to call-tool routing
- [ ] Run all tests and verify 100% passing (including existing 42 tmux tests)
- [ ] Format code with topiary
- [ ] Update tools/tmux/README.md with new tools documentation
- [ ] Create PR for Phase 2 changes

## Tool Schemas (Draft)

### create_window
```json
{
  "name": "create_window",
  "description": "Create a new window in a tmux session. Optionally specify window name, working directory, and target index.",
  "input_schema": {
    "type": "object",
    "properties": {
      "session": {
        "type": "string",
        "description": "Session name or ID"
      },
      "name": {
        "type": "string",
        "description": "Name for the new window (optional)"
      },
      "directory": {
        "type": "string",
        "description": "Working directory for the new window (optional, defaults to session's default)"
      },
      "target": {
        "type": "integer",
        "description": "Target window index (optional, defaults to next available)"
      },
      "detached": {
        "type": "boolean",
        "description": "Don't switch to the new window (optional, default: false)"
      }
    },
    "required": ["session"]
  }
}
```

### split_pane
```json
{
  "name": "split_pane",
  "description": "Split a pane in a tmux window horizontally or vertically. Optionally specify working directory and size.",
  "input_schema": {
    "type": "object",
    "properties": {
      "session": {
        "type": "string",
        "description": "Session name or ID"
      },
      "direction": {
        "type": "string",
        "enum": ["horizontal", "vertical"],
        "description": "Split direction (horizontal creates left/right panes, vertical creates top/bottom panes)"
      },
      "window": {
        "type": "string",
        "description": "Window name or ID (optional, defaults to current window)"
      },
      "pane": {
        "type": "string",
        "description": "Pane ID to split (optional, defaults to current pane)"
      },
      "directory": {
        "type": "string",
        "description": "Working directory for the new pane (optional)"
      },
      "size": {
        "type": "integer",
        "description": "Size of new pane as percentage (optional, defaults to 50)"
      },
      "detached": {
        "type": "boolean",
        "description": "Don't switch to the new pane (optional, default: false)"
      }
    },
    "required": ["session", "direction"]
  }
}
```

## Testing Approach

### Manual Testing Commands
```bash
# Test create_window
nu tools/tmux/mod.nu call-tool create_window '{"session": "test"}'
nu tools/tmux/mod.nu call-tool create_window '{"session": "test", "name": "mywindow"}'
nu tools/tmux/mod.nu call-tool create_window '{"session": "test", "directory": "/tmp"}'

# Test split_pane
nu tools/tmux/mod.nu call-tool split_pane '{"session": "test", "direction": "horizontal"}'
nu tools/tmux/mod.nu call-tool split_pane '{"session": "test", "direction": "vertical"}'
nu tools/tmux/mod.nu call-tool split_pane '{"session": "test", "direction": "horizontal", "directory": "/tmp"}'
```

### Test Cases (TDD)
**create_window tests:**
- ✅ Basic window creation (session only)
- ✅ Window creation with custom name
- ✅ Window creation with working directory
- ❌ Error: non-existent session
- ❌ Error: invalid parameters

**split_pane tests:**
- ✅ Horizontal split (default)
- ✅ Vertical split
- ✅ Split with working directory
- ✅ Split with size percentage (optional enhancement)
- ❌ Error: non-existent session
- ❌ Error: invalid direction

### Edge Cases
- Non-existent session (should return clear error)
- Invalid window/pane targeting (should return clear error)
- Invalid directory path (tmux creates it automatically)
- Very long window names (truncated by tmux)
- Special characters in names (tmux handles escaping)

## Questions & Decisions

### Q: Should we support all tmux flags?
**A**: Start with most common flags (`-n`, `-c`, `-d`, `-h/-v`, `-p`). Can add more later if needed.

### Q: How to return created window/pane info?
**A**: Parse tmux output using `-F` flag with format variables:
- `new-window -dPF '#{window_id}:#{window_index}'` returns window info
- `split-window -dPF '#{pane_id}'` returns new pane ID

### Q: Should split_pane default to horizontal or vertical?
**A**: Horizontal (left/right) is tmux default with `-h` flag, so require explicit direction parameter to avoid confusion.

### Q: Should we support running commands in new windows/panes?
**A**: Not in initial implementation. Users can use `send_and_capture` after creating window/pane. Can add in future if needed.

### Q: Module organization - new file or existing?
**A**: Create `workload.nu` for window/pane management operations. Keeps code organized and follows SOLID principles (Single Responsibility).

## Implementation Notes

### Tmux Command Reference
```bash
# Create window
tmux new-window -t session:               # Basic
tmux new-window -t session: -n mywindow   # With name
tmux new-window -t session: -c /tmp       # With directory
tmux new-window -dPF '#{window_id}'       # Detached with output

# Split pane
tmux split-window -t session: -h          # Horizontal
tmux split-window -t session: -v          # Vertical
tmux split-window -t session: -c /tmp     # With directory
tmux split-window -t session: -p 30       # 30% size
tmux split-window -dPF '#{pane_id}'       # Detached with output
```

### Response Format
Return JSON with created resource info:
```json
{
  "success": true,
  "window_id": "@1",
  "window_index": 2,
  "message": "Created window 'mywindow' in session 'test'"
}
```

For errors:
```json
{
  "success": false,
  "error": "session not found: test",
  "message": "Session 'test' does not exist. Use list_sessions to see available sessions."
}
```

## Progress Tracking

**Current Phase**: Planning & Setup
**Next Task**: Create feature branch
**Completed**: Research (Context7)
