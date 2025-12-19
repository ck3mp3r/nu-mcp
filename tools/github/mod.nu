# GitHub MCP Tool - provides GitHub workflow and PR management tools
# Wraps the gh CLI for MCP integration

use utils.nu *
use workflows.nu *

# Default main command
def main [] {
  help main
}

# List available MCP tools
def "main list-tools" [] {
  [
    # Workflow tools
    {
      name: "list_workflows"
      description: "List workflow files in the repository"
      input_schema: {
        type: "object"
        properties: {
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
      }
    }
    {
      name: "list_workflow_runs"
      description: "List recent workflow runs with optional filtering by workflow, branch, or status"
      input_schema: {
        type: "object"
        properties: {
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
          workflow: {
            type: "string"
            description: "Filter by workflow name or filename (optional)"
          }
          branch: {
            type: "string"
            description: "Filter by branch name (optional)"
          }
          status: {
            type: "string"
            description: "Filter by status: queued, in_progress, completed, success, failure, cancelled (optional)"
            enum: ["queued" "in_progress" "completed" "success" "failure" "cancelled"]
          }
          limit: {
            type: "integer"
            description: "Maximum number of runs to return (default: 20)"
            minimum: 1
            maximum: 100
          }
        }
      }
    }
    {
      name: "get_workflow_run"
      description: "View details of a specific workflow run including jobs and steps"
      input_schema: {
        type: "object"
        properties: {
          run_id: {
            type: "integer"
            description: "The ID of the workflow run to view"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["run_id"]
      }
    }
    {
      name: "run_workflow"
      description: "Trigger a workflow run. Requires destructive safety mode."
      input_schema: {
        type: "object"
        properties: {
          workflow: {
            type: "string"
            description: "Workflow name or filename (e.g., 'ci.yaml' or 'CI')"
          }
          ref: {
            type: "string"
            description: "Branch or tag to run the workflow on (optional, defaults to default branch)"
          }
          inputs: {
            type: "object"
            description: "Input parameters for workflow_dispatch triggers (optional)"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["workflow"]
      }
    }
    # PR tools
    {
      name: "list_prs"
      description: "List pull requests with optional filtering by state, author, or base branch"
      input_schema: {
        type: "object"
        properties: {
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
          state: {
            type: "string"
            description: "Filter by state: open, closed, merged, all (default: open)"
            enum: ["open" "closed" "merged" "all"]
          }
          author: {
            type: "string"
            description: "Filter by author username (optional)"
          }
          base: {
            type: "string"
            description: "Filter by base branch (optional)"
          }
          limit: {
            type: "integer"
            description: "Maximum number of PRs to return (default: 30)"
            minimum: 1
            maximum: 100
          }
        }
      }
    }
    {
      name: "get_pr"
      description: "View details of a specific pull request"
      input_schema: {
        type: "object"
        properties: {
          number: {
            type: "integer"
            description: "The PR number to view"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["number"]
      }
    }
    {
      name: "get_pr_checks"
      description: "View CI/check status on a pull request"
      input_schema: {
        type: "object"
        properties: {
          number: {
            type: "integer"
            description: "The PR number to view checks for"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["number"]
      }
    }
    {
      name: "create_pr"
      description: "Create a new pull request. Requires destructive safety mode."
      input_schema: {
        type: "object"
        properties: {
          title: {
            type: "string"
            description: "Title for the pull request"
          }
          body: {
            type: "string"
            description: "Body/description for the pull request (optional)"
          }
          base: {
            type: "string"
            description: "Base branch to merge into (optional, defaults to default branch)"
          }
          head: {
            type: "string"
            description: "Head branch containing changes (optional, defaults to current branch)"
          }
          draft: {
            type: "boolean"
            description: "Create as draft PR (optional, default: false)"
          }
          labels: {
            type: "array"
            items: {type: "string"}
            description: "Labels to add to the PR (optional)"
          }
          reviewers: {
            type: "array"
            items: {type: "string"}
            description: "Reviewers to request (optional)"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["title"]
      }
    }
    {
      name: "update_pr"
      description: "Update an existing pull request. Requires destructive safety mode."
      input_schema: {
        type: "object"
        properties: {
          number: {
            type: "integer"
            description: "The PR number to update"
          }
          title: {
            type: "string"
            description: "New title for the PR (optional)"
          }
          body: {
            type: "string"
            description: "New body for the PR (optional)"
          }
          add_labels: {
            type: "array"
            items: {type: "string"}
            description: "Labels to add (optional)"
          }
          remove_labels: {
            type: "array"
            items: {type: "string"}
            description: "Labels to remove (optional)"
          }
          add_reviewers: {
            type: "array"
            items: {type: "string"}
            description: "Reviewers to add (optional)"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["number"]
      }
    }
  ] | to json
}

# Call a specific tool with arguments
def "main call-tool" [
  tool_name: string
  args: any = {}
] {
  # Parse args if string
  let parsed_args = if ($args | describe) == "string" {
    $args | from json
  } else {
    $args
  }

  match $tool_name {
    "list_workflows" => {
      let path = get-optional $parsed_args "path" ""
      list-workflows --path $path
    }
    "list_workflow_runs" => {
      let path = get-optional $parsed_args "path" ""
      let workflow = get-optional $parsed_args "workflow" ""
      let branch = get-optional $parsed_args "branch" ""
      let status = get-optional $parsed_args "status" ""
      let limit = get-optional $parsed_args "limit" 0
      list-workflow-runs --path $path --workflow $workflow --branch $branch --status $status --limit $limit
    }
    "get_workflow_run" => {
      let run_id = $parsed_args | get run_id
      let path = get-optional $parsed_args "path" ""
      get-workflow-run $run_id --path $path
    }
    "run_workflow" => {
      let workflow = $parsed_args | get workflow
      let path = get-optional $parsed_args "path" ""
      let ref = get-optional $parsed_args "ref" ""
      let inputs = get-optional $parsed_args "inputs" {}
      run-workflow $workflow --path $path --ref $ref --inputs $inputs | to json
    }
    "list_prs" => {
      error make {msg: "list_prs not yet implemented"}
    }
    "get_pr" => {
      error make {msg: "get_pr not yet implemented"}
    }
    "get_pr_checks" => {
      error make {msg: "get_pr_checks not yet implemented"}
    }
    "create_pr" => {
      error make {msg: "create_pr not yet implemented"}
    }
    "update_pr" => {
      error make {msg: "update_pr not yet implemented"}
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
