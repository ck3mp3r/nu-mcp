# Tmux Phase 3: Destructive Operations & Layout Management

## Overview
- **Purpose**: Add complete lifecycle management (kill operations) and layout control with mandatory safety protections
- **Target Users**: Developers who want AI-assisted tmux workspace management with safety guarantees
- **External Dependencies**: tmux (CLI tool, already used by existing tmux tools)

## Key Safety Requirement

**CRITICAL**: LLMs must ONLY be able to destroy resources THEY created, not user-created resources.

### Safety Mechanism Design

**Approach: Resource Tracking via Pane Titles**

When creating windows/panes, we'll set a special marker in the pane title:
```
MCP_CREATED=<timestamp>
```

**Implementation:**
1. **Creation Phase** (`create_window`, `split_pane`):
   - After creating, immediately set pane title with marker
   - Use `select-pane -T "MCP_CREATED=<timestamp>"`
   - Store creation metadata

2. **Destruction Phase** (`kill_*` operations):
   - **BEFORE** killing, check pane title for `MCP_CREATED` marker
   - If marker missing → **REJECT** with error: "Cannot destroy user-created resource"
   - If marker present → **ALLOW** with `--force` flag
   - If `--force` not provided → **REJECT** with warning

3. **Verification**:
   - Use `list-panes -F '#{pane_title}'` to check marker
   - Parse marker timestamp for additional safety checks

### Force Flag Behavior

**All destructive operations require `--force` flag:**
```json
{
  "session": "dev",
  "window": "frontend",
  "force": true  // REQUIRED for destruction
}
```

**Without `--force`:**
```json
{
  "success": false,
  "error": "Destructive operation requires explicit --force flag",
  "message": "This operation will permanently delete the resource. Add 'force: true' to proceed."
}
```

## Capabilities

- [ ] Research tmux kill-* and layout commands
- [ ] `kill_session` - Terminate entire session (with MCP_CREATED check)
- [ ] `kill_window` - Remove window from session (with MCP_CREATED check)
- [ ] `kill_pane` - Close pane (with MCP_CREATED check)
- [ ] `select_layout` - Apply predefined layouts to windows
- [ ] Update `create_window` and `split_pane` to mark resources with MCP_CREATED

## Module Structure

- `workload.nu`: Window/pane creation/deletion and layout management (EXTEND existing)
  - Add `kill-session`, `kill-window`, `kill-pane` functions
  - Add `select-layout` function
  - Add `mark-resource-created` helper
  - Add `check-resource-ownership` helper
- `mod.nu`: MCP interface and routing (UPDATE with new tools)
- `tests/test_workload.nu`: Tests for new operations (EXTEND existing)

## Context7 Research

- [x] Research tmux kill commands: `kill-session`, `kill-window`, `kill-pane`
- [x] Research layout commands: `select-layout`, available layouts
- [ ] Research pane title setting: `select-pane -T`
- [ ] Research pane title querying: `list-panes -F '#{pane_title}'`

## Security Considerations

**CRITICAL SAFETY REQUIREMENTS:**

1. **Resource Ownership Tracking**
   - All MCP-created resources MUST be marked with `MCP_CREATED` marker
   - Destruction ONLY allowed for MCP-created resources
   - User-created resources are PROTECTED

2. **Explicit Opt-In**
   - ALL destructive operations require `--force` flag
   - No destructive operations by default
   - Clear error messages when force is missing

3. **LLM Warning**
   - Tool descriptions MUST include: "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING"
   - Descriptions MUST explain what gets destroyed
   - Descriptions MUST state "cannot be undone"

4. **Safety Checks**
   - Verify resource exists before destruction
   - Verify MCP_CREATED marker present
   - Verify force flag provided
   - Return detailed error if any check fails

## TDD Milestones

### Setup
- [ ] Research tmux commands and safety mechanisms
- [ ] Create implementation plan
- [ ] Create feature branch: `feature/tmux-phase3-destructive-layout`

### Update Creation Tools (Prerequisite)
- [ ] **RED**: Write test for create_window marking resources
- [ ] **GREEN**: Update create_window to set MCP_CREATED marker
- [ ] **RED**: Write test for split_pane marking resources
- [ ] **GREEN**: Update split_pane to set MCP_CREATED marker

### Safety Infrastructure
- [ ] **RED**: Write test for check-resource-ownership helper
- [ ] **GREEN**: Implement check-resource-ownership helper
- [ ] **RED**: Write test for force flag validation
- [ ] **GREEN**: Implement force flag validation

### kill_pane Tool
- [ ] **RED**: Write test for kill_pane with MCP-created pane + force
- [ ] **GREEN**: Implement basic kill_pane
- [ ] **RED**: Write test for kill_pane rejecting user-created pane
- [ ] **GREEN**: Add ownership check to kill_pane
- [ ] **RED**: Write test for kill_pane rejecting without force flag
- [ ] **GREEN**: Add force flag requirement to kill_pane

### kill_window Tool
- [ ] **RED**: Write test for kill_window with MCP-created window + force
- [ ] **GREEN**: Implement basic kill_window
- [ ] **RED**: Write test for kill_window rejecting user-created window
- [ ] **GREEN**: Add ownership check to kill_window
- [ ] **RED**: Write test for kill_window rejecting without force flag
- [ ] **GREEN**: Add force flag requirement to kill_window

### kill_session Tool
- [ ] **RED**: Write test for kill_session with MCP-created session + force
- [ ] **GREEN**: Implement basic kill_session
- [ ] **RED**: Write test for kill_session rejecting user-created session
- [ ] **GREEN**: Add ownership check to kill_session
- [ ] **RED**: Write test for kill_session rejecting without force flag
- [ ] **GREEN**: Add force flag requirement to kill_session

### select_layout Tool
- [ ] **RED**: Write test for select_layout with each predefined layout (5 tests)
- [ ] **GREEN**: Implement select_layout with all 5 layouts
- [ ] **RED**: Write test for invalid layout name error
- [ ] **GREEN**: Add layout validation

### Integration & Polish
- [ ] Add all tools to mod.nu tool schemas
- [ ] Add all tools to mod.nu call-tool routing
- [ ] Run all tests and verify 100% passing
- [ ] Format code with topiary
- [ ] Update tools/tmux/README.md
- [ ] Create PR for Phase 3 changes

## Tool Schemas (Draft)

### kill_session
```json
{
  "name": "kill_session",
  "description": "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING. Permanently terminates a tmux session and all windows/panes within it, killing all running processes. This operation cannot be undone. Can ONLY destroy sessions created by MCP (marked with MCP_CREATED). Requires explicit --force flag.",
  "input_schema": {
    "type": "object",
    "properties": {
      "session": {
        "type": "string",
        "description": "Session name or ID to terminate"
      },
      "force": {
        "type": "boolean",
        "description": "REQUIRED: Must be true to confirm destruction. Without this flag, the operation will be rejected."
      }
    },
    "required": ["session", "force"]
  }
}
```

### kill_window
```json
{
  "name": "kill_window",
  "description": "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING. Permanently closes a tmux window and terminates all processes in its panes. This operation cannot be undone. Can ONLY destroy windows created by MCP (marked with MCP_CREATED). Requires explicit --force flag. If this is the last window in the session, the session will be terminated.",
  "input_schema": {
    "type": "object",
    "properties": {
      "session": {
        "type": "string",
        "description": "Session name or ID"
      },
      "window": {
        "type": "string",
        "description": "Window name or index to kill"
      },
      "force": {
        "type": "boolean",
        "description": "REQUIRED: Must be true to confirm destruction. Without this flag, the operation will be rejected."
      }
    },
    "required": ["session", "window", "force"]
  }
}
```

### kill_pane
```json
{
  "name": "kill_pane",
  "description": "DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING. Permanently closes a tmux pane and terminates the process running in it. This operation cannot be undone. Can ONLY destroy panes created by MCP (marked with MCP_CREATED). Requires explicit --force flag. If this is the last pane in the window, the window will be closed.",
  "input_schema": {
    "type": "object",
    "properties": {
      "session": {
        "type": "string",
        "description": "Session name or ID"
      },
      "window": {
        "type": "string",
        "description": "Window name or ID (optional, defaults to current window)"
      },
      "pane": {
        "type": "string",
        "description": "Pane ID to kill (optional, defaults to current pane)"
      },
      "force": {
        "type": "boolean",
        "description": "REQUIRED: Must be true to confirm destruction. Without this flag, the operation will be rejected."
      }
    },
    "required": ["session", "force"]
  }
}
```

### select_layout
```json
{
  "name": "select_layout",
  "description": "Apply a predefined layout to a tmux window, reorganizing all panes. Available layouts: 'even-horizontal' (panes side-by-side), 'even-vertical' (panes stacked), 'main-horizontal' (main pane top, others below), 'main-vertical' (main pane left, others right), 'tiled' (grid layout).",
  "input_schema": {
    "type": "object",
    "properties": {
      "session": {
        "type": "string",
        "description": "Session name or ID"
      },
      "window": {
        "type": "string",
        "description": "Window name or ID (optional, defaults to current window)"
      },
      "layout": {
        "type": "string",
        "enum": ["even-horizontal", "even-vertical", "main-horizontal", "main-vertical", "tiled"],
        "description": "Layout name to apply"
      }
    },
    "required": ["session", "layout"]
  }
}
```

## Testing Approach

### Test Organization

**Extend existing test_workload.nu with new sections:**

```nushell
# =============================================================================
# Resource marking tests (prerequisite for safety)
# =============================================================================

# =============================================================================
# Safety helper tests
# =============================================================================

# =============================================================================
# kill_pane tests
# =============================================================================

# =============================================================================
# kill_window tests
# =============================================================================

# =============================================================================
# kill_session tests
# =============================================================================

# =============================================================================
# select_layout tests
# =============================================================================
```

### Test Cases (Estimated: 25-30 tests total)

**Resource Marking (4 tests):**
- ✅ create_window sets MCP_CREATED marker
- ✅ split_pane sets MCP_CREATED marker
- ✅ Marker includes timestamp
- ✅ Marker retrievable via list-panes

**Safety Helpers (4 tests):**
- ✅ check-resource-ownership detects MCP marker
- ✅ check-resource-ownership rejects missing marker
- ✅ Force flag validation accepts true
- ✅ Force flag validation rejects false/missing

**kill_pane (5 tests):**
- ✅ kill_pane succeeds with MCP-created pane + force
- ✅ kill_pane with window and pane targeting
- ❌ kill_pane rejects user-created pane
- ❌ kill_pane rejects without force flag
- ❌ kill_pane rejects non-existent pane

**kill_window (5 tests):**
- ✅ kill_window succeeds with MCP-created window + force
- ✅ kill_window by window name
- ❌ kill_window rejects user-created window
- ❌ kill_window rejects without force flag
- ❌ kill_window rejects non-existent window

**kill_session (5 tests):**
- ✅ kill_session succeeds with MCP-created session + force
- ✅ kill_session by session name
- ❌ kill_session rejects user-created session
- ❌ kill_session rejects without force flag
- ❌ kill_session rejects non-existent session

**select_layout (7 tests):**
- ✅ select_layout even-horizontal
- ✅ select_layout even-vertical
- ✅ select_layout main-horizontal
- ✅ select_layout main-vertical
- ✅ select_layout tiled
- ✅ select_layout with specific window
- ❌ select_layout rejects invalid layout name

### Edge Cases
- Last pane in window (window closes)
- Last window in session (session closes)
- Concurrent operations on same resource
- Malformed MCP_CREATED markers
- Timestamps in markers (future: expiration?)

## Implementation Notes

### Tmux Command Reference

```bash
# Set pane title (for marking)
tmux select-pane -t session:window.pane -T "MCP_CREATED=1735059600"

# Get pane title
tmux list-panes -t session:window -F '#{pane_id}:#{pane_title}'

# Kill operations
tmux kill-pane -t session:window.pane
tmux kill-window -t session:window
tmux kill-session -t session

# Layout operations
tmux select-layout -t session:window even-horizontal
tmux select-layout -t session:window even-vertical
tmux select-layout -t session:window main-horizontal
tmux select-layout -t session:window main-vertical
tmux select-layout -t session:window tiled
```

### Safety Check Pseudocode

```nushell
def check-resource-ownership [session: string, window?: string, pane?: string] {
  # Build target
  let target = build-target $session $window $pane
  
  # Get pane title
  let title = exec_tmux_command ['list-panes' '-t' $target '-F' '#{pane_title}']
  
  # Check for MCP_CREATED marker
  if ($title | str contains 'MCP_CREATED=') {
    { owned: true, timestamp: (extract-timestamp $title) }
  } else {
    { owned: false, error: "Resource not created by MCP" }
  }
}
```

### Response Format

**Success:**
```json
{
  "success": true,
  "operation": "kill_window",
  "resource": "dev:frontend",
  "message": "Window 'frontend' in session 'dev' has been terminated"
}
```

**Error - Missing Force:**
```json
{
  "success": false,
  "error": "Destructive operation requires explicit --force flag",
  "message": "This operation will permanently delete window 'frontend'. Add 'force: true' to proceed.",
  "resource": "dev:frontend"
}
```

**Error - Not MCP-Created:**
```json
{
  "success": false,
  "error": "Cannot destroy user-created resource",
  "message": "Window 'frontend' was not created by MCP and cannot be destroyed. Only MCP-created resources (marked with MCP_CREATED) can be deleted.",
  "resource": "dev:frontend"
}
```

## Questions & Decisions

### Q: Should we track creation at session level too?
**A**: YES - When creating a session (future feature), mark the first window/pane with MCP_CREATED. This allows session-level tracking.

### Q: What if user renames a pane title?
**A**: The MCP_CREATED marker would be lost, and the pane becomes "user-owned" (protected). This is acceptable behavior - user intervention = user ownership.

### Q: Should we allow killing sessions even if some windows weren't MCP-created?
**A**: NO - If ANY window in the session lacks MCP_CREATED marker, reject the kill_session operation. This prevents accidental destruction of user work.

### Q: Should layouts require force flag?
**A**: NO - Layouts are non-destructive (just reorganize panes). No force flag needed.

### Q: What about timestamps in markers?
**A**: Include timestamp for future use (expiration, age-based policies), but don't enforce any policies in Phase 3. Keep it simple.

## Progress Tracking

**Current Phase**: Planning & Research
**Next Task**: Create feature branch and start TDD

## Expected Outcomes

After Phase 3:
- ✅ Complete lifecycle management (create/destroy)
- ✅ Mandatory safety protections (ownership tracking)
- ✅ Explicit opt-in for destruction (force flag)
- ✅ Layout management for workspace organization
- ✅ ~25-30 new tests, all passing
- ✅ ~73+ total tmux tests
- ✅ ~258+ total tests across all tools

**Estimated Time**: 6-8 hours with TDD (larger scope than Phase 2)
