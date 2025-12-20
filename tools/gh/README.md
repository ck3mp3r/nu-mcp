# gh MCP Tool

MCP tool for GitHub workflow and pull request management via the `gh` CLI.

## Quick Start

**Prerequisites:** 
- `gh` CLI installed and authenticated (`gh auth login`)
- Git repository with GitHub remote

**Configuration:**
```json
{
  "mcpServers": {
    "gh": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/gh"]
    }
  }
}
```

## Safety Modes

The tool operates in one of two modes controlled by `MCP_GITHUB_MODE`:

| Mode | Tools | Configuration |
|------|-------|---------------|
| **readwrite** (default) | All 11 tools | No env var needed (or `MCP_GITHUB_MODE=readwrite`) |
| **readonly** | 7 read-only tools | Set `MCP_GITHUB_MODE=readonly` |

**Note:** The `merge_pr` tool has an additional safety requirement beyond readwrite mode - it requires explicit `confirm_merge: true` to prevent accidental merges.

### Read-Only Mode (Production)

For production environments where you only want to read GitHub data:

```json
{
  "mcpServers": {
    "gh-readonly": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/gh"],
      "env": {
        "MCP_GITHUB_MODE": "readonly"
      }
    }
  }
}
```

### Read-Write Mode (Default)

Default mode allows all operations including creating/updating PRs and triggering workflows:

```json
{
  "mcpServers": {
    "gh": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/tools/gh"]
      // No MCP_GITHUB_MODE needed - defaults to readwrite
    }
  }
}
```

**Important Notes:**
- `close_pr` and `reopen_pr` are reversible operations
- `merge_pr` is **IRREVERSIBLE** and requires explicit `confirm_merge: true` flag
- `upsert_pr` and `run_workflow` are non-destructive (won't delete data)

## Available Tools

### Workflow Tools

#### Read-Only Tools

**`list_workflows`** - List workflow files in the repository
- `path` (optional): Path to git repository (defaults to current directory)

**`list_workflow_runs`** - List recent workflow runs with filtering
- `path` (optional): Path to git repository
- `workflow` (optional): Filter by workflow name or filename
- `branch` (optional): Filter by branch name
- `status` (optional): Filter by status (queued, in_progress, completed, success, failure, cancelled)
- `limit` (optional): Maximum number of runs to return (default: 20, max: 100)

**`get_workflow_run`** - View details of a specific workflow run including jobs
- `run_id` (required): The workflow run ID
- `path` (optional): Path to git repository

#### Write Tools

**`run_workflow`** - Trigger a workflow run
- `workflow` (required): Workflow name or filename (e.g., 'ci.yaml' or 'CI')
- `ref` (optional): Branch or tag to run on (defaults to default branch)
- `inputs` (optional): Input parameters for workflow_dispatch triggers (object)
- `path` (optional): Path to git repository

### Pull Request Tools

#### Read-Only Tools

**`list_prs`** - List pull requests with filtering
- `path` (optional): Path to git repository
- `state` (optional): Filter by state (open, closed, merged, all)
- `author` (optional): Filter by author username
- `base` (optional): Filter by base branch
- `limit` (optional): Maximum number of PRs to return (default: 30, max: 100)

**`get_pr`** - View details of a specific pull request
- `number` (required): The PR number
- `path` (optional): Path to git repository

**`get_pr_checks`** - View CI/check status on a pull request
- `number` (required): The PR number to view checks for
- `path` (optional): Path to git repository

#### Write Tools

**`upsert_pr`** - Create or update a pull request (idempotent)
- `title` (required): Title for the pull request
- `body` (optional): Body/description for the pull request
- `base` (optional): Base branch to merge into (defaults to default branch)
- `head` (optional): Head branch with changes (defaults to current branch)
- `draft` (optional): Create as draft PR - only applies when creating new PR (default: false)
- `labels` (optional): Labels to add to the PR (array of strings)
- `reviewers` (optional): Reviewers to request/add (array of strings)
- `path` (optional): Path to git repository

**How `upsert_pr` works:**
1. Gets the head branch (from `--head` parameter or current git branch)
2. Checks if a PR already exists for that head branch
3. If PR exists: updates it with new title/body/labels/reviewers
4. If no PR exists: creates a new one

This makes it safe to call repeatedly - it won't create duplicate PRs.

**`close_pr`** - Close a pull request without merging (reversible)
- `number` (required): PR number to close
- `comment` (optional): Closing comment
- `delete_branch` (optional): Delete branch after close (default: false)
- `path` (optional): Path to git repository

**`reopen_pr`** - Reopen a closed pull request (reversible)
- `number` (required): PR number to reopen
- `comment` (optional): Reopening comment
- `path` (optional): Path to git repository

**`merge_pr`** - Merge a pull request ⚠️ **IRREVERSIBLE - REQUIRES EXPLICIT CONFIRMATION**
- `number` (required): PR number to merge
- `confirm_merge` (required): **MUST be `true`** - safety flag to prevent accidental merges
- `squash` (optional): Squash commits (default strategy if none specified)
- `merge` (optional): Create merge commit
- `rebase` (optional): Rebase and merge
- `delete_branch` (optional): Delete branch after merge (default: false)
- `auto` (optional): Enable auto-merge when requirements met (default: false)
- `path` (optional): Path to git repository

**⚠️ CRITICAL: merge_pr Safety Requirements**

This operation is **IRREVERSIBLE** and requires explicit user permission:

1. **ALWAYS ask the user first** before calling `merge_pr`
2. **MUST set `confirm_merge: true`** - the tool will fail without this
3. The merge **CANNOT be undone** once completed
4. Default merge strategy is **squash** (use `merge: true` or `rebase: true` for alternatives)

**Example workflow:**
```
LLM: "I can merge PR #123 using squash merge. Do you want me to proceed?"
User: "Yes, merge it"
LLM: Calls merge_pr(number: 123, confirm_merge: true)
```

If you forget to ask, the tool will return an error explicitly telling you to ask the user first.

## Usage Examples

These examples show how to call the tools from an MCP client (e.g., Claude Desktop, using JavaScript/TypeScript). The `await` keyword is JavaScript syntax for async operations in the MCP client, not Nushell syntax.

### List Recent Workflow Runs

```javascript
// List all recent workflow runs
await use_mcp_tool("gh", "list_workflow_runs", {});

// List runs for a specific workflow
await use_mcp_tool("gh", "list_workflow_runs", {
  workflow: "CI",
  limit: 10
});

// List failed runs on main branch
await use_mcp_tool("gh", "list_workflow_runs", {
  branch: "main",
  status: "failure"
});
```

### Trigger a Workflow

```javascript
// Trigger workflow on default branch
await use_mcp_tool("gh", "run_workflow", {
  workflow: "ci.yaml"
});

// Trigger workflow on specific branch with inputs
await use_mcp_tool("gh", "run_workflow", {
  workflow: "deploy.yaml",
  ref: "staging",
  inputs: {
    environment: "staging",
    version: "v1.2.3"
  }
});
```

### Manage Pull Requests

```javascript
// List open PRs
await use_mcp_tool("gh", "list_prs", {
  state: "open"
});

// Get PR details
await use_mcp_tool("gh", "get_pr", {
  number: 42
});

// Get PR check status
await use_mcp_tool("gh", "get_pr_checks", {
  number: 42
});

// Create or update a PR (idempotent)
await use_mcp_tool("gh", "upsert_pr", {
  title: "Add new feature",
  body: "This PR adds...",
  head: "feature-branch",
  base: "main",
  labels: ["enhancement"],
  reviewers: ["user1", "user2"]
});

// Close a PR
await use_mcp_tool("gh", "close_pr", {
  number: 42,
  comment: "Closing this PR because..."
});

// Reopen a PR
await use_mcp_tool("gh", "reopen_pr", {
  number: 42,
  comment: "Reopening after fixes"
});

// Merge a PR (REQUIRES EXPLICIT CONFIRMATION)
// Step 1: LLM asks user: "Can I merge PR #42?"
// Step 2: User confirms: "Yes"
// Step 3: LLM calls with confirm_merge: true
await use_mcp_tool("gh", "merge_pr", {
  number: 42,
  confirm_merge: true,  // REQUIRED - must explicitly confirm
  squash: true,         // Optional - squash is default anyway
  delete_branch: true   // Optional - delete branch after merge
});
```

## Error Handling

All tools return descriptive error messages when operations fail:

- **Authentication errors**: Ensure `gh auth login` has been run
- **Permission errors**: Check GitHub repository permissions
- **Not found errors**: Verify workflow/PR numbers and repository paths
- **Label errors**: Ensure labels exist in the repository before using them

## Testing

The tool includes comprehensive tests (37 tests covering all functionality):

```bash
nu tools/gh/tests/run_tests.nu
# Results: 37/37 passed, 0 failed
```

### Manual Testing with Nushell

You can also test tools directly with Nushell (no `await` keyword needed - Nushell is synchronous):

```bash
# List workflows
nu tools/gh/mod.nu call-tool list_workflows '{}'

# List recent workflow runs
nu tools/gh/mod.nu call-tool list_workflow_runs '{}'

# Get PR details
nu tools/gh/mod.nu call-tool get_pr '{"number": 42}'
```

## Development

See [Tool Development Guide](../../docs/tool-development.md) for:
- Architecture overview
- Adding new tools
- Testing patterns
- Mock infrastructure

## Implementation Details

### Module Structure

```
tools/gh/
├── mod.nu              # MCP interface (list-tools, call-tool)
├── utils.nu            # gh CLI wrapper, safety modes
├── workflows.nu        # Workflow operations
├── prs.nu              # PR operations  
├── formatters.nu       # Human-readable output formatting (optional)
└── tests/              # Test suite (27 tests)
    ├── mocks.nu        # Mock gh/git CLI commands
    ├── test_helpers.nu # Sample data for tests
    ├── run_tests.nu    # Test runner
    ├── test_workflows.nu
    └── test_prs.nu
```

### Safety Implementation

Tools check permissions before execution:

```nushell
# In each tool function
check-tool-permission "tool_name"
```

The `is-tool-allowed` function in `utils.nu` determines if a tool can run based on `MCP_GITHUB_MODE`.

### Mock Testing Strategy

Tests use environment variables to mock CLI commands:

```nushell
# Mock format: MOCK_<command>_<args_with_underscores>
MOCK_gh_pr_list___state_open = '{"exit_code": 0, "output": "[...]"}'
MOCK_git_branch___show_current = '{"exit_code": 0, "output": "main"}'
```

This allows comprehensive testing without requiring actual GitHub API calls.
