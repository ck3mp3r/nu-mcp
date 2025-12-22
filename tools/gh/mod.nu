# gh MCP Tool - provides GitHub workflow and PR management via gh CLI
# Wraps the gh CLI for MCP integration

use utils.nu *
use workflows.nu *
use prs.nu *
use releases.nu *

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
      description: "Trigger a workflow run"
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
      name: "upsert_pr"
      description: "Create or update a pull request. If a PR already exists for the head branch, it will be updated. Otherwise, a new PR is created."
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
            description: "Create as draft PR - only applies when creating new PR (optional, default: false)"
          }
          labels: {
            type: "array"
            items: {type: "string"}
            description: "Labels to add to the PR (optional)"
          }
          reviewers: {
            type: "array"
            items: {type: "string"}
            description: "Reviewers to request/add (optional)"
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
      name: "close_pr"
      description: "Close a pull request without merging (reversible via reopen_pr)"
      input_schema: {
        type: "object"
        properties: {
          number: {
            type: "integer"
            description: "The PR number to close"
          }
          comment: {
            type: "string"
            description: "Closing comment (optional)"
          }
          delete_branch: {
            type: "boolean"
            description: "Delete the local and remote branch after close (optional, default: false)"
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
      name: "reopen_pr"
      description: "Reopen a closed pull request (reversible via close_pr)"
      input_schema: {
        type: "object"
        properties: {
          number: {
            type: "integer"
            description: "The PR number to reopen"
          }
          comment: {
            type: "string"
            description: "Reopening comment (optional)"
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
      name: "merge_pr"
      description: "Merge a pull request (IRREVERSIBLE - requires explicit confirmation)"
      input_schema: {
        type: "object"
        properties: {
          number: {
            type: "integer"
            description: "The PR number to merge"
          }
          confirm_merge: {
            type: "boolean"
            description: "REQUIRED: Must be true to proceed. This operation is IRREVERSIBLE. Always ask user permission first."
          }
          squash: {
            type: "boolean"
            description: "Squash commits and merge (optional, default strategy if none specified)"
          }
          merge: {
            type: "boolean"
            description: "Create a merge commit (optional)"
          }
          rebase: {
            type: "boolean"
            description: "Rebase and merge (optional)"
          }
          delete_branch: {
            type: "boolean"
            description: "Delete the local and remote branch after merge (optional, default: false)"
          }
          auto: {
            type: "boolean"
            description: "Enable auto-merge when requirements are met (optional, default: false)"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
        required: ["number" "confirm_merge"]
      }
    }
    # Release tools
    {
      name: "list_releases"
      description: "List releases in the repository with optional filtering"
      input_schema: {
        type: "object"
        properties: {
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
          limit: {
            type: "integer"
            description: "Maximum number of releases to return (optional, default: 30)"
            minimum: 1
            maximum: 100
          }
          exclude_drafts: {
            type: "boolean"
            description: "Exclude draft releases (optional, default: false)"
          }
          exclude_prereleases: {
            type: "boolean"
            description: "Exclude pre-releases (optional, default: false)"
          }
        }
      }
    }
    {
      name: "get_release"
      description: "View details of a specific release by tag, or latest release if no tag provided"
      input_schema: {
        type: "object"
        properties: {
          tag: {
            type: "string"
            description: "Release tag (e.g., 'v1.0.0'). Omit to get latest release."
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
        }
      }
    }
    {
      name: "create_release"
      description: "Create a new GitHub release"
      input_schema: {
        type: "object"
        properties: {
          tag: {
            type: "string"
            description: "Release tag (e.g., 'v1.0.0')"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
          title: {
            type: "string"
            description: "Release title (optional)"
          }
          notes: {
            type: "string"
            description: "Release notes (optional)"
          }
          draft: {
            type: "boolean"
            description: "Save as draft instead of publishing (optional, default: false)"
          }
          prerelease: {
            type: "boolean"
            description: "Mark as prerelease (optional, default: false)"
          }
          generate_notes: {
            type: "boolean"
            description: "Auto-generate notes via GitHub API (optional, default: false)"
          }
          latest: {
            type: "boolean"
            description: "Mark as latest release (optional)"
          }
          not_latest: {
            type: "boolean"
            description: "Explicitly mark as NOT latest release (optional)"
          }
          target: {
            type: "string"
            description: "Target branch or commit SHA (optional, default: default branch). Short commit SHAs will be automatically resolved to full 40-character SHAs as required by GitHub API."
          }
        }
        required: ["tag"]
      }
    }
    {
      name: "edit_release"
      description: "Edit a release (update notes, title, draft/prerelease status)"
      input_schema: {
        type: "object"
        properties: {
          tag: {
            type: "string"
            description: "Release tag to edit (e.g., 'v1.0.0')"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
          notes: {
            type: "string"
            description: "Release notes (optional)"
          }
          title: {
            type: "string"
            description: "Release title (optional)"
          }
          draft: {
            type: "boolean"
            description: "Mark as draft (optional)"
          }
          no_draft: {
            type: "boolean"
            description: "Publish the release (set draft=false) (optional)"
          }
          prerelease: {
            type: "boolean"
            description: "Mark as prerelease (optional)"
          }
        }
        required: ["tag"]
      }
    }
    {
      name: "delete_release"
      description: "Delete a release (DESTRUCTIVE - requires MCP_GITHUB_MODE=destructive)"
      input_schema: {
        type: "object"
        properties: {
          tag: {
            type: "string"
            description: "Release tag to delete (e.g., 'v1.0.0')"
          }
          path: {
            type: "string"
            description: "Path to the git repository directory (optional, defaults to current directory)"
          }
          cleanup_tag: {
            type: "boolean"
            description: "Also delete the git tag (optional, default: false)"
          }
        }
        required: ["tag"]
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
      let workflow = get-optional $parsed_args "workflow" null
      let branch = get-optional $parsed_args "branch" null
      let status = get-optional $parsed_args "status" null
      let limit = get-optional $parsed_args "limit" null
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
      let ref = get-optional $parsed_args "ref" null
      let inputs = get-optional $parsed_args "inputs" {}
      run-workflow $workflow --path $path --ref $ref --inputs $inputs | to json
    }
    "list_prs" => {
      let path = get-optional $parsed_args "path" null
      let state = get-optional $parsed_args "state" null
      let author = get-optional $parsed_args "author" null
      let base = get-optional $parsed_args "base" null
      let limit = get-optional $parsed_args "limit" null
      list-prs --path $path --state $state --author $author --base $base --limit $limit
    }
    "get_pr" => {
      let number = $parsed_args | get number
      let path = get-optional $parsed_args "path" null
      get-pr $number --path $path
    }
    "get_pr_checks" => {
      let number = $parsed_args | get number
      let path = get-optional $parsed_args "path" null
      get-pr-checks $number --path $path
    }
    "upsert_pr" => {
      let title = $parsed_args | get title
      let path = get-optional $parsed_args "path" null
      let body = get-optional $parsed_args "body" null
      let base = get-optional $parsed_args "base" null
      let head = get-optional $parsed_args "head" null
      let draft = get-optional $parsed_args "draft" false
      let labels = get-optional $parsed_args "labels" []
      let reviewers = get-optional $parsed_args "reviewers" []
      if $draft {
        upsert-pr $title --path $path --body $body --base $base --head $head --draft --labels $labels --reviewers $reviewers
      } else {
        upsert-pr $title --path $path --body $body --base $base --head $head --labels $labels --reviewers $reviewers
      }
    }
    "close_pr" => {
      let number = $parsed_args | get number
      let path = get-optional $parsed_args "path" null
      let comment = get-optional $parsed_args "comment" null
      let delete_branch = get-optional $parsed_args "delete_branch" false
      if $delete_branch {
        close-pr $number --path $path --comment $comment --delete-branch
      } else {
        close-pr $number --path $path --comment $comment
      }
    }
    "reopen_pr" => {
      let number = $parsed_args | get number
      let path = get-optional $parsed_args "path" null
      let comment = get-optional $parsed_args "comment" null
      reopen-pr $number --path $path --comment $comment
    }
    "merge_pr" => {
      let number = $parsed_args | get number
      let path = get-optional $parsed_args "path" null
      let confirm_merge = get-optional $parsed_args "confirm_merge" false
      let squash = get-optional $parsed_args "squash" false
      let merge = get-optional $parsed_args "merge" false
      let rebase = get-optional $parsed_args "rebase" false
      let delete_branch = get-optional $parsed_args "delete_branch" false
      let auto = get-optional $parsed_args "auto" false

      if $delete_branch and $auto {
        merge-pr $number --path $path --confirm-merge=$confirm_merge --squash=$squash --merge=$merge --rebase=$rebase --delete-branch --auto
      } else if $delete_branch {
        merge-pr $number --path $path --confirm-merge=$confirm_merge --squash=$squash --merge=$merge --rebase=$rebase --delete-branch
      } else if $auto {
        merge-pr $number --path $path --confirm-merge=$confirm_merge --squash=$squash --merge=$merge --rebase=$rebase --auto
      } else {
        merge-pr $number --path $path --confirm-merge=$confirm_merge --squash=$squash --merge=$merge --rebase=$rebase
      }
    }
    "list_releases" => {
      let path = get-optional $parsed_args "path" ""
      let limit = get-optional $parsed_args "limit" null
      let exclude_drafts = get-optional $parsed_args "exclude_drafts" false
      let exclude_prereleases = get-optional $parsed_args "exclude_prereleases" false

      if $limit != null {
        if $exclude_drafts and $exclude_prereleases {
          list-releases --path $path --limit $limit --exclude-drafts --exclude-prereleases
        } else if $exclude_drafts {
          list-releases --path $path --limit $limit --exclude-drafts
        } else if $exclude_prereleases {
          list-releases --path $path --limit $limit --exclude-prereleases
        } else {
          list-releases --path $path --limit $limit
        }
      } else {
        if $exclude_drafts and $exclude_prereleases {
          list-releases --path $path --exclude-drafts --exclude-prereleases
        } else if $exclude_drafts {
          list-releases --path $path --exclude-drafts
        } else if $exclude_prereleases {
          list-releases --path $path --exclude-prereleases
        } else {
          list-releases --path $path
        }
      }
    }
    "get_release" => {
      let tag = get-optional $parsed_args "tag" null
      let path = get-optional $parsed_args "path" ""

      if $tag != null {
        get-release $tag --path $path
      } else {
        get-release --path $path
      }
    }
    "create_release" => {
      let tag = $parsed_args | get tag
      let path = get-optional $parsed_args "path" ""
      let title = get-optional $parsed_args "title" null
      let notes = get-optional $parsed_args "notes" null
      let draft = get-optional $parsed_args "draft" false
      let prerelease = get-optional $parsed_args "prerelease" false
      let generate_notes = get-optional $parsed_args "generate_notes" false
      let latest = get-optional $parsed_args "latest" false
      let not_latest = get-optional $parsed_args "not_latest" false
      let target = get-optional $parsed_args "target" null

      # Pass all parameters - Nushell handles nulls for optional named params
      # and boolean flags can be explicitly set with --flag=true/false
      create-release $tag --path $path --title $title --notes $notes --target $target --draft=$draft --prerelease=$prerelease --generate-notes=$generate_notes --latest=$latest --not-latest=$not_latest
    }
    "edit_release" => {
      let tag = $parsed_args | get tag
      let path = get-optional $parsed_args "path" ""
      let notes = get-optional $parsed_args "notes" null
      let title = get-optional $parsed_args "title" null
      let draft = get-optional $parsed_args "draft" false
      let no_draft = get-optional $parsed_args "no_draft" false
      let prerelease = get-optional $parsed_args "prerelease" false

      # Pass all parameters - Nushell handles nulls and boolean flag values
      edit-release $tag --path $path --title $title --notes $notes --draft=$draft --no-draft=$no_draft --prerelease=$prerelease
    }
    "delete_release" => {
      let tag = $parsed_args | get tag
      let path = get-optional $parsed_args "path" ""
      let cleanup_tag = get-optional $parsed_args "cleanup_tag" false

      if $cleanup_tag {
        delete-release $tag --path $path --cleanup-tag
      } else {
        delete-release $tag --path $path
      }
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
