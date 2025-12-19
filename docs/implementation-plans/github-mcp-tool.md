# GitHub MCP Tool Implementation Plan

## Overview
- **Purpose**: Provide MCP tools to interact with GitHub workflows and pull requests via the `gh` CLI
- **Target Users**: AI agents that need to check CI status, trigger workflows, and manage PRs
- **External Dependencies**: `gh` CLI (GitHub CLI)

## Capabilities

### Workflow Tools
- [x] `list_workflows`: List workflow files in the repository
- [x] `list_workflow_runs`: List recent workflow runs with filtering
- [x] `get_workflow_run`: View details of a specific workflow run
- [ ] `run_workflow`: Trigger a workflow run with optional inputs (destructive)

### PR Tools
- [ ] `list_prs`: List pull requests with filtering
- [ ] `get_pr`: View PR details
- [ ] `get_pr_checks`: View CI/check status on a PR
- [ ] `create_pr`: Create a new pull request (destructive)
- [ ] `update_pr`: Update PR title/body/labels/reviewers (destructive)

## Common Parameters

All tools accept:
- **path** (string, optional): Path to git repo directory, defaults to current working directory

## Module Structure

```
tools/github/
├── mod.nu              # MCP interface (list-tools, call-tool)
├── utils.nu            # gh CLI wrapper, safety modes, path handling
├── formatters.nu       # Output formatting (future use)
├── tests/
│   ├── mocks.nu        # Mock gh CLI commands
│   ├── test_helpers.nu # Test setup/teardown utilities
│   ├── run_tests.nu    # Test runner
│   ├── test_workflows.nu
│   └── test_prs.nu
└── README.md
```

## Context7 Research
- [x] Research gh CLI: workflow commands, pr commands, JSON output
- [x] Research existing mock patterns in nu-mcp (c5t/mocks.nu)

## Security Considerations

### Safety Modes
- `MCP_GITHUB_MODE` environment variable controls allowed operations
- **readonly** (default): Only read operations allowed
- **destructive**: All operations allowed including workflow triggers and PR mutations

### Tool Classification
- **Readonly**: `list_workflows`, `list_workflow_runs`, `get_workflow_run`, `list_prs`, `get_pr`, `get_pr_checks`
- **Destructive**: `run_workflow`, `create_pr`, `update_pr`

## Milestones

### Phase 1: Foundation
- [x] Milestone 1: Implementation plan document
- [x] Milestone 2: Basic module structure (mod.nu skeleton)
- [x] Milestone 3: Mock infrastructure (tests/mocks.nu)
- [x] Milestone 4: Test helpers and runner

### Phase 2: Workflow Tools (TDD)
- [x] Milestone 5: utils.nu with gh CLI wrapper and safety modes
- [x] Milestone 6: list_workflows tool
- [x] Milestone 7: list_workflow_runs tool
- [x] Milestone 8: get_workflow_run tool
- [ ] Milestone 9: run_workflow tool

### Phase 3: PR Tools (TDD)
- [ ] Milestone 10: list_prs tool
- [ ] Milestone 11: get_pr tool
- [ ] Milestone 12: get_pr_checks tool
- [ ] Milestone 13: create_pr tool
- [ ] Milestone 14: update_pr tool

### Phase 4: Polish
- [ ] Milestone 15: formatters.nu for human-readable output
- [ ] Milestone 16: README.md documentation
- [ ] Milestone 17: Integration testing with MCP server

## Testing Approach

### Mock Strategy
Environment variable-based mocking following c5t pattern:
```nushell
# Set mock for specific gh command
MOCK_gh_workflow_list___json_id_name_state: '{"exit_code":0,"output":"[...]"}'
```

### Test Categories
1. **Unit tests**: Individual function behavior with mocks
2. **Error handling**: Invalid inputs, CLI failures, permission denied
3. **Safety mode tests**: Verify readonly mode blocks destructive operations

## gh CLI Commands Reference

### Workflows
```bash
gh workflow list --json id,name,path,state
gh run list --json databaseId,status,conclusion,workflowName,headBranch --limit 20
gh run view <run-id> --json attempt,conclusion,status,jobs,name
gh workflow run <workflow> --ref <branch> -f key=value
```

### Pull Requests
```bash
gh pr list --json number,title,state,author,headRefName,baseRefName
gh pr view <number> --json number,title,body,state,author,labels,reviewers
gh pr create --title "..." --body "..." --base main --head feature
gh pr edit <number> --title "..." --add-label "..." --add-reviewer "..."
gh pr checks <number> --json name,state,conclusion
```

## Questions & Decisions

### Decided
1. **Repository targeting**: Use `path` parameter to specify repo directory (defaults to cwd)
2. **Output format**: JSON for structured data (consistent with k8s/argocd tools)
3. **Safety modes**: readonly (default) and destructive

### Open
- None currently
