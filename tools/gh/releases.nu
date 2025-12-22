# GitHub release operations
# Functions for listing, viewing, creating, editing, and deleting releases

use utils.nu *
use formatters.nu *

# List releases in the repository
export def list-releases [
  --path: string # Path to git repo (optional, defaults to cwd)
  --limit: int # Maximum number of releases to return
  --exclude-drafts # Exclude draft releases
  --exclude-prereleases # Exclude pre-releases
] {
  check-tool-permission "list_releases"

  mut args = [
    "release"
    "list"
    "--json"
    "tagName,name,isDraft,isPrerelease,isLatest,createdAt,publishedAt"
  ]

  if $limit != null {
    $args = ($args | append ["--limit" ($limit | into string)])
  }

  if $exclude_drafts {
    $args = ($args | append "--exclude-drafts")
  }

  if $exclude_prereleases {
    $args = ($args | append "--exclude-pre-releases")
  }

  let result = run-gh $args --path ($path | default "")
  let releases = $result | from json
  format-release-list $releases
}

# Get details of a specific release (or latest if no tag provided)
export def get-release [
  tag?: string # Release tag (e.g., "v1.0.0"), omit for latest
  --path: string # Path to git repo (optional, defaults to cwd)
] {
  check-tool-permission "get_release"

  mut args = ["release" "view"]

  if $tag != null {
    $args = ($args | append $tag)
  }

  $args = (
    $args | append [
      "--json"
      "tagName,name,body,isDraft,isPrerelease,createdAt,publishedAt,author,url,assets"
    ]
  )

  let result = run-gh $args --path ($path | default "")
  let release = $result | from json
  format-release $release
}

# Create a new release
export def create-release [
  tag: string # Release tag (e.g., "v1.0.0")
  --path: string # Path to git repo (optional, defaults to cwd)
  --title: string # Release title
  --notes: string # Release notes
  --draft # Save as draft instead of publishing
  --prerelease # Mark as prerelease
  --generate-notes # Auto-generate notes via GitHub API
  --latest # Mark as latest
  --not-latest # Mark as not latest
  --target: string # Target branch or commit SHA
] {
  check-tool-permission "create_release"

  mut args = ["release" "create" $tag]

  if $title != null {
    $args = ($args | append ["--title" $title])
  }

  if $notes != null {
    $args = ($args | append ["--notes" $notes])
  }

  if $draft {
    $args = ($args | append "--draft")
  }

  if $prerelease {
    $args = ($args | append "--prerelease")
  }

  if $generate_notes {
    $args = ($args | append "--generate-notes")
  }

  if $latest {
    $args = ($args | append "--latest")
  }

  if $not_latest {
    $args = ($args | append "--latest=false")
  }

  if $target != null {
    $args = ($args | append ["--target" $target])
  }

  run-gh $args --path ($path | default "")
}

# Edit a release
export def edit-release [
  tag: string # Release tag to edit
  --path: string # Path to git repo (optional, defaults to cwd)
  --notes: string # Release notes
  --title: string # Release title
  --draft # Mark as draft
  --no-draft # Publish (set draft=false)
  --prerelease # Mark as prerelease
] {
  check-tool-permission "edit_release"

  mut args = ["release" "edit" $tag]

  if $notes != null {
    $args = ($args | append ["--notes" $notes])
  }

  if $title != null {
    $args = ($args | append ["--title" $title])
  }

  if $draft {
    $args = ($args | append "--draft")
  }

  if $no_draft {
    $args = ($args | append "--draft=false")
  }

  if $prerelease {
    $args = ($args | append "--prerelease")
  }

  run-gh $args --path ($path | default "")
}

# Delete a release
export def delete-release [
  tag: string # Release tag to delete
  --path: string # Path to git repo (optional, defaults to cwd)
  --cleanup-tag # Also delete the git tag
] {
  check-tool-permission "delete_release"

  mut args = ["release" "delete" $tag "--yes"]

  if $cleanup_tag {
    $args = ($args | append "--cleanup-tag")
  }

  run-gh $args --path ($path | default "")
}
