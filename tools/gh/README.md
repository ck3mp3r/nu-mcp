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
| **readwrite** (default) | All 8 tools | No env var needed (or `MCP_GITHUB_MODE=readwrite`) |
| **readonly** | 6 read-only tools | Set `MCP_GITHUB_MODE=readonly` |

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

**Note:** All write operations are non-destructive (no delete/force operations).

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

## Usage Examples

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
```

## Error Handling

All tools return descriptive error messages when operations fail:

- **Authentication errors**: Ensure `gh auth login` has been run
- **Permission errors**: Check GitHub repository permissions
- **Not found errors**: Verify workflow/PR numbers and repository paths
- **Label errors**: Ensure labels exist in the repository before using them

## Testing

The tool includes comprehensive tests (27 tests covering all functionality):

```bash
nu tools/gh/tests/run_tests.nu
# Results: 27/27 passed, 0 failed
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
