# GitHub PR operations
# Functions for interacting with GitHub Pull Requests

use utils.nu *

# List pull requests in the repository
export def list-prs [
  --path: string # Path to git repo (optional, defaults to cwd)
  --state: string # Filter by state: open, closed, merged, all
  --author: string # Filter by author username
  --base: string # Filter by base branch
  --limit: int # Maximum number of PRs to return
] {
  check-tool-permission "list_prs"

  mut args = [
    "pr"
    "list"
    "--json"
    "number,title,state,author,headRefName,baseRefName,createdAt,isDraft"
  ]

  if $state != null {
    $args = ($args | append ["--state" $state])
  }

  if $author != null {
    $args = ($args | append ["--author" $author])
  }

  if $base != null {
    $args = ($args | append ["--base" $base])
  }

  if $limit != null {
    $args = ($args | append ["--limit" ($limit | into string)])
  }

  run-gh $args --path ($path | default "")
}

# Get details of a specific pull request
export def get-pr [
  number: int
  --path: string # Path to git repo (optional, defaults to cwd)
] {
  check-tool-permission "get_pr"

  let args = [
    "pr"
    "view"
    ($number | into string)
    "--json"
    "number,title,body,state,author,headRefName,baseRefName,createdAt,updatedAt,isDraft,labels,reviewRequests,url"
  ]

  run-gh $args --path ($path | default "")
}

# Get CI/check status on a pull request
export def get-pr-checks [
  number: int
  --path: string # Path to git repo (optional, defaults to cwd)
] {
  check-tool-permission "get_pr_checks"

  let args = [
    "pr"
    "checks"
    ($number | into string)
    "--json"
    "name,state,bucket,workflow,completedAt"
  ]

  run-gh $args --path ($path | default "")
}

# Update an existing pull request (internal helper)
def update-pr-internal [
  number: int
  --path: string # Path to git repo (optional, defaults to cwd)
  --title: string # New title
  --body: string # New body
  --add-labels: list<string> = [] # Labels to add
  --remove-labels: list<string> = [] # Labels to remove
  --add-reviewers: list<string> = [] # Reviewers to add
] {
  mut args = ["pr" "edit" ($number | into string)]

  if $title != null {
    $args = ($args | append ["--title" $title])
  }

  if $body != null {
    $args = ($args | append ["--body" $body])
  }

  for label in $add_labels {
    $args = ($args | append ["--add-label" $label])
  }

  for label in $remove_labels {
    $args = ($args | append ["--remove-label" $label])
  }

  for reviewer in $add_reviewers {
    $args = ($args | append ["--add-reviewer" $reviewer])
  }

  # gh pr edit doesn't support --json, get the PR after editing
  run-gh $args --path ($path | default "")

  # Return the PR details after update
  get-pr $number --path ($path | default "")
}

# Get current git branch name
def get-current-branch [--path: string = ""] {
  if $path != "" {
    cd $path
  }
  git branch --show-current | str trim
}

# Find existing PR by head branch
def find-pr-by-head [
  head: string
  --path: string = ""
] {
  let args = [
    "pr"
    "list"
    "--head"
    $head
    "--json"
    "number,headRefName"
  ]

  let result = run-gh $args --path $path
  let prs = $result | from json

  if ($prs | length) > 0 {
    $prs | first
  } else {
    null
  }
}

# Upsert (create or update) a pull request
# If a PR already exists for the head branch, updates it
# Otherwise creates a new PR
export def upsert-pr [
  title: string
  --path: string # Path to git repo (optional, defaults to cwd)
  --body: string # PR description
  --base: string # Base branch to merge into
  --head: string # Head branch with changes (defaults to current branch)
  --draft # Create as draft PR (only applies to new PRs)
  --labels: list<string> = [] # Labels to add
  --reviewers: list<string> = [] # Reviewers to request/add
] {
  check-tool-permission "upsert_pr"

  let repo_path = $path | default ""

  # Get head branch - use provided or current git branch
  let head_branch = if $head != null {
    $head
  } else {
    get-current-branch --path $repo_path
  }

  # Check if PR exists for this head branch
  let existing_pr = find-pr-by-head $head_branch --path $repo_path

  if $existing_pr != null {
    # Update existing PR
    update-pr-internal $existing_pr.number --path $repo_path --title $title --body $body --add-labels $labels --add-reviewers $reviewers
  } else {
    # Create new PR
    mut args = ["pr" "create" "--title" $title "--head" $head_branch]

    if $body != null {
      $args = ($args | append ["--body" $body])
    }

    if $base != null {
      $args = ($args | append ["--base" $base])
    }

    if $draft {
      $args = ($args | append ["--draft"])
    }

    for label in $labels {
      $args = ($args | append ["--label" $label])
    }

    for reviewer in $reviewers {
      $args = ($args | append ["--reviewer" $reviewer])
    }

    # gh pr create doesn't support --json, it returns URL to stdout
    let output = run-gh $args --path $repo_path

    # Extract PR number from URL (format: https://github.com/owner/repo/pull/123)
    let pr_number = $output | str trim | split row "/" | last

    {number: ($pr_number | into int) url: ($output | str trim)} | to json
  }
}
