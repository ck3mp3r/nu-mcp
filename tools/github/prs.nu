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
    "name,state,conclusion"
  ]

  run-gh $args --path ($path | default "")
}

# Create a new pull request
export def create-pr [
  title: string
  --path: string # Path to git repo (optional, defaults to cwd)
  --body: string # PR description
  --base: string # Base branch to merge into
  --head: string # Head branch with changes
  --draft # Create as draft PR
  --labels: list<string> = [] # Labels to add
  --reviewers: list<string> = [] # Reviewers to request
] {
  check-tool-permission "create_pr"

  mut args = ["pr" "create" "--title" $title]

  if $body != null {
    $args = ($args | append ["--body" $body])
  }

  if $base != null {
    $args = ($args | append ["--base" $base])
  }

  if $head != null {
    $args = ($args | append ["--head" $head])
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

  $args = ($args | append ["--json" "number,url"])

  run-gh $args --path ($path | default "")
}

# Update an existing pull request
export def update-pr [
  number: int
  --path: string # Path to git repo (optional, defaults to cwd)
  --title: string # New title
  --body: string # New body
  --add-labels: list<string> = [] # Labels to add
  --remove-labels: list<string> = [] # Labels to remove
  --add-reviewers: list<string> = [] # Reviewers to add
] {
  check-tool-permission "update_pr"

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

  $args = ($args | append ["--json" "number,url"])

  run-gh $args --path ($path | default "")
}
