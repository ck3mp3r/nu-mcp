# GitHub workflow operations
# Functions for interacting with GitHub Actions workflows

use utils.nu *

# List workflows in the repository
export def list-workflows [
  --path: string = ""
] {
  check-tool-permission "list_workflows"

  let args = [
    "workflow"
    "list"
    "--json"
    "id,name,path,state"
  ]

  run-gh $args --path $path
}

# List workflow runs with optional filtering
export def list-workflow-runs [
  --path: string = ""
  --workflow: string = ""
  --branch: string = ""
  --status: string = ""
  --limit: int = 0
] {
  check-tool-permission "list_workflow_runs"

  mut args = [
    "run"
    "list"
    "--json"
    "databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt"
  ]

  if $workflow != "" {
    $args = ($args | append ["--workflow" $workflow])
  }

  if $branch != "" {
    $args = ($args | append ["--branch" $branch])
  }

  if $status != "" {
    $args = ($args | append ["--status" $status])
  }

  if $limit > 0 {
    $args = ($args | append ["--limit" ($limit | into string)])
  }

  run-gh $args --path $path
}

# Get details of a specific workflow run
export def get-workflow-run [
  run_id: int
  --path: string = ""
] {
  check-tool-permission "get_workflow_run"

  let args = [
    "run"
    "view"
    ($run_id | into string)
    "--json"
    "databaseId,displayTitle,status,conclusion,workflowName,headBranch,headSha,event,createdAt,updatedAt,url,jobs"
  ]

  run-gh $args --path $path
}

# Trigger a workflow run
export def run-workflow [
  workflow: string
  --path: string = ""
  --ref: string = ""
  --inputs: record = {}
] {
  check-tool-permission "run_workflow"

  mut args = ["workflow" "run" $workflow]

  if $ref != "" {
    $args = ($args | append ["--ref" $ref])
  }

  # Add inputs as -f key=value pairs
  if not ($inputs | is-empty) {
    for entry in ($inputs | transpose key value) {
      $args = ($args | append ["-f" $"($entry.key)=($entry.value)"])
    }
  }

  run-gh $args --path $path

  # Return success message (run_workflow doesn't return JSON)
  {success: true message: $"Workflow '($workflow)' triggered successfully"}
}
