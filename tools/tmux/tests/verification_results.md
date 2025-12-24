# Tmux Command Format Verification Results

Generated: 2025-12-24 18:05:24
Tmux Version: tmux 3.6a

## Summary

- Total: 17
- Passed: 16 ✅
- Failed: 0 ❌
- Partial: 1 ⚠️

## Detailed Results

### ✅ PASS set-option -pt <pane_id> (CORRECT format)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS set-option -pt session:pane_id (WRONG format)

- **Expected:** fail
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS show-options -pt <pane_id> (CORRECT format)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS show-options -pt <pane_id> with nonexistent option (should fail)

- **Expected:** fail
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS kill-pane -t <pane_id> (CORRECT format)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ⚠️ PARTIAL kill-pane -t session:pane_id (WRONG format - should fail)

- **Expected:** fail
- **Actual:** success but unverified
- **Reason:** Verification failed: {msg: Data cannot be accessed with a cell path, debug: IncompatiblePathAccess { type_name: "nothing", span: Span { start: 161712, end: 161719 } }, raw: IncompatiblePathAccess { type_name: "nothing", span: Span { start: 161712, end: 161719 } }, rendered: Error: nu::shell::incompatible_path_access

  x Data cannot be accessed with a cell path
     ,-[/Users/christian/Projects/ck3mp3r/nu-mcp/tools/tmux/tests/manual_verification.nu:250:32]
 249 |     # But if we do, cleanup
 250 |     ^tmux kill-pane -t $result.pane_id
     :                                ^^^|^^^
     :                                   `-- nothing doesn't support cell paths
 251 |     false
     `----
, json: {"msg":"Data cannot be accessed with a cell path","labels":[{"text":"nothing doesn't support cell paths","span":{"start":161712,"end":161719}}],"code":"nu::shell::incompatible_path_access","url":null,"help":null,"inner":[]}}

### ✅ PASS set-option -wt session:window (window-level)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS set-option -t session (session-level)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS new-window -t session: (with trailing colon)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS split-window -t session: (current window)

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS split-window -t session:window

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS select-layout -t session: even-horizontal

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS select-layout -t session: even-vertical

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS select-layout -t session: main-horizontal

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS select-layout -t session: main-vertical

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS select-layout -t session: tiled

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded

### ✅ PASS Format variables in list-sessions

- **Expected:** success
- **Actual:** success
- **Reason:** Command and verification succeeded
