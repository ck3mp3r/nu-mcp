# GitHub workflow operations
# Functions for interacting with GitHub Actions workflows

use utils.nu *

# List workflows in the repository
export def list-workflows [
  --path: string # Path to git repo (optional, defaults to cwd)
] {
  check-tool-permission "list_workflows"

  let args = [
    "workflow"
    "list"
    "--json"
    "id,name,path,state"
  ]

  run-gh $args --path ($path | default "")
}

# List workflow runs with optional filtering
export def list-workflow-runs [
  --path: string # Path to git repo (optional, defaults to cwd)
  --workflow: string # Filter by workflow name or filename
  --branch: string # Filter by branch name
  --status: string # Filter by status
  --limit: int # Maximum number of runs to return
] {
  check-tool-permission "list_workflow_runs"

  mut args = [
    "run"
    "list"
    "--json"
    "databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt"
  ]

  if $workflow != null {
    $args = ($args | append ["--workflow" $workflow])
  }

  if $branch != null {
    $args = ($args | append ["--branch" $branch])
  }

  if $status != null {
    $args = ($args | append ["--status" $status])
  }

  if $limit != null {
    $args = ($args | append ["--limit" ($limit | into string)])
  }

  run-gh $args --path ($path | default "")
}

# Get details of a specific workflow run
export def get-workflow-run [
  run_id: int
  --path: string # Path to git repo (optional, defaults to cwd)
] {
  check-tool-permission "get_workflow_run"

  let args = [
    "run"
    "view"
    ($run_id | into string)
    "--json"
    "databaseId,displayTitle,status,conclusion,workflowName,headBranch,headSha,event,createdAt,updatedAt,url,jobs"
  ]

  run-gh $args --path ($path | default "")
}

# Trigger a workflow run
export def run-workflow [
  workflow: string
  --path: string # Path to git repo (optional, defaults to cwd)
  --ref: string # Branch or tag to run on
  --inputs: record = {} # Input parameters for workflow_dispatch
] {
  check-tool-permission "run_workflow"

  mut args = ["workflow" "run" $workflow]

  if $ref != null {
    $args = ($args | append ["--ref" $ref])
  }

  # Add inputs as -f key=value pairs
  if not ($inputs | is-empty) {
    for entry in ($inputs | transpose key value) {
      $args = ($args | append ["-f" $"($entry.key)=($entry.value)"])
    }
  }

  run-gh $args --path ($path | default "")

  # Return success message (run_workflow doesn't return JSON)
  {success: true message: $"Workflow '($workflow)' triggered successfully"}
}
