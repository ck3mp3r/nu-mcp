# K8s Delegation Feature Implementation Plan

## Overview
- **Purpose**: Allow k8s tools to return kubectl commands instead of executing them, enabling delegation to other tools (like tmux)
- **Target Users**: LLMs that want to execute commands in specific contexts (tmux panes, remote sessions, etc.)
- **Design Philosophy**: Pipeline-friendly, testable, composable

## Goals
1. **Refactor `run-kubectl`**: Accept piped parameters instead of function parameters for better composability
2. **Add delegation mode**: Tools can return command strings instead of executing them
3. **LLM-controlled**: Delegation mode is controlled via tool parameter, not environment variable
4. **Maintain compatibility**: Existing behavior (execute mode) remains default

## Capabilities
- [ ] `run-kubectl` accepts piped record with parameters
- [ ] All k8s tools accept optional `delegate` boolean parameter
- [ ] When `delegate: true`, return the kubectl command string
- [ ] When `delegate: false` (default), execute and return results
- [ ] Command building logic is reusable/testable

## Architecture Changes

### Before (Function Parameters)
```nushell
export def run-kubectl [
    args: list<string>
    --namespace: string = ""
    --context: string = ""
    --output: string = "json"
] {
    # Build and execute command
}
```

### After (Piped Record)
```nushell
export def run-kubectl [] {
    let params = $in  # Accept piped input
    # params.args, params.namespace, params.context, params.output, params.delegate
    
    # Build command
    let cmd = build-kubectl-command $params
    
    # Execute or return based on delegate mode
    if $params.delegate? == true {
        $cmd  # Return command string
    } else {
        execute-kubectl-command $cmd $params.output  # Execute and parse
    }
}
```

## Module Structure Changes

### utils.nu
- `run-kubectl` - Main entry point (accepts piped record)
- `build-kubectl-command` - Pure function to build command (NEW)
- `execute-kubectl-command` - Execute and parse output (NEW, extracted)
- All existing helper functions remain

### Tool Schema Changes
Add optional `delegate` parameter to all tools:
```nushell
{
    name: "kube_get"
    input_schema: {
        properties: {
            # ... existing parameters ...
            delegate: {
                type: "boolean"
                description: "If true, return the kubectl command instead of executing it. Useful for delegation to other tools like tmux."
                default: false
            }
        }
    }
}
```

## Implementation Milestones

- [ ] Milestone 1: Extract command building logic from run-kubectl
- [ ] Milestone 2: Create build-kubectl-command helper
- [ ] Milestone 3: Create execute-kubectl-command helper
- [ ] Milestone 4: Refactor run-kubectl to accept piped input
- [ ] Milestone 5: Add delegate parameter to one tool (kube_get) as proof of concept
- [ ] Milestone 6: Update all tools to support delegation
- [ ] Milestone 7: Update all tool schemas with delegate parameter
- [ ] Milestone 8: Update documentation and README
- [ ] Milestone 9: Test both execution and delegation modes

## Design Decisions

### Why Piped Input?
- **Composability**: Can transform parameters before passing to run-kubectl
- **Testability**: Easy to test command building without execution
- **Swappable**: Can create mock implementations that don't execute
- **Functional**: Pure functions are easier to reason about

### Why Tool Parameter Instead of Environment Variable?
- **LLM Control**: LLM can decide per-call whether to delegate
- **Explicit**: Clear in the tool invocation what mode is being used
- **Flexible**: Same tool can be used in both modes in the same session
- **Standard**: Follows JSON schema / parameter passing conventions

### Default Behavior
- `delegate` defaults to `false` (execute mode)
- Maintains backward compatibility
- Existing tools continue to work as-is

## Example Usage

### Execution Mode (Default)
```nushell
# LLM calls tool normally
{
    resourceType: "pods"
    namespace: "default"
}
# Returns: Pod data (executed)
```

### Delegation Mode
```nushell
# LLM calls tool with delegate flag
{
    resourceType: "pods"
    namespace: "default"
    delegate: true
}
# Returns: "kubectl get pods --namespace default --output json"
```

### LLM Delegation Workflow
```nushell
# 1. LLM asks k8s tool for command
kube_get { resourceType: "pods", delegate: true }
# Returns: "kubectl get pods --namespace default --output json"

# 2. LLM passes command to tmux tool
tmux_send_and_capture {
    session: "dev"
    command: "kubectl get pods --namespace default --output json"
}
# Executes in tmux session
```

## Testing Approach

### Unit Tests
- Test `build-kubectl-command` with various parameter combinations
- Verify command string construction is correct
- Test delegation returns command string
- Test execution mode still works

### Integration Tests
- Test actual kubectl execution
- Test delegation returns valid commands
- Test commands can be executed via shell
- Test with different contexts, namespaces, outputs

### Edge Cases
- Missing optional parameters
- Invalid delegate value (non-boolean)
- Command injection attempts
- Empty args list

## Migration Path

1. **Phase 1**: Add new helpers without breaking changes
2. **Phase 2**: Refactor run-kubectl to use helpers internally
3. **Phase 3**: Update one tool (kube-get) to test delegation
4. **Phase 4**: Roll out to all tools
5. **Phase 5**: Update documentation

## Questions & Decisions

### Q: Should we validate the command before returning in delegate mode?
**A**: Yes, basic validation (non-empty, valid kubectl syntax) but don't execute

### Q: Should delegate mode respect safety modes?
**A**: Yes, still check is-tool-allowed before returning command

### Q: What format should the command be returned in?
**A**: Plain string, ready to execute in a shell

### Q: Should we support dry-run mode separately?
**A**: No, delegate mode serves that purpose. Use `delegate: true` to see the command

## Security Considerations

- Delegation mode still respects safety modes (readonly/non-destructive/destructive)
- Command building must prevent injection attacks
- Validate all parameters before building command
- Don't expose sensitive data in command strings (secrets, tokens)

## Documentation Updates

### README.md
- Add section on delegation mode
- Explain when to use delegation vs execution
- Show example workflow with tmux
- Document the `delegate` parameter on all tools

### Tool Schemas
- Add clear description of `delegate` parameter
- Indicate it's optional with default `false`
- Explain use case (delegation to other tools)

## Success Criteria

- [ ] `run-kubectl` accepts piped parameters
- [ ] All tools support `delegate` parameter
- [ ] Delegation mode returns valid kubectl commands
- [ ] Execution mode continues to work as before
- [ ] No breaking changes to existing tool calls
- [ ] Documentation clearly explains both modes
- [ ] LLMs can successfully use delegation mode with tmux
