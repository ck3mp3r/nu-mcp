# GitHub data formatting and display utilities

# Format workflow status with indicator
def format-workflow-state [state: string] {
  match $state {
    "active" => "active"
    "disabled_manually" => "disabled (manual)"
    "disabled_inactivity" => "disabled (inactive)"
    _ => $state
  }
}

# Format workflow run status with indicator
def format-run-status [status: string conclusion: string] {
  if $status == "completed" {
    match $conclusion {
      "success" => "success"
      "failure" => "failure"
      "cancelled" => "cancelled"
      "skipped" => "skipped"
      "timed_out" => "timed out"
      _ => $conclusion
    }
  } else {
    match $status {
      "queued" => "queued"
      "in_progress" => "running"
      "waiting" => "waiting"
      _ => $status
    }
  }
}

# Format PR state
def format-pr-state [state: string is_draft: bool] {
  if $is_draft {
    "draft"
  } else {
    $state | str downcase
  }
}

# Format check conclusion - use conclusion if present, otherwise state
def format-check-state [state: string conclusion: string] {
  let status = if $conclusion != "" { $conclusion } else { $state }
  match ($status | str downcase) {
    "success" => "pass"
    "failure" => "fail"
    $other => $other
  }
}

# Format relative time
def format-relative-time [timestamp: string] {
  try {
    let dt = $timestamp | into datetime
    let now = date now
    let diff = $now - $dt

    if $diff < 1min {
      "just now"
    } else if $diff < 1hr {
      let mins = ($diff / 1min) | math floor
      $"($mins)m ago"
    } else if $diff < 24hr {
      let hours = ($diff / 1hr) | math floor
      $"($hours)h ago"
    } else if $diff < 7day {
      let days = ($diff / 1day) | math floor
      $"($days)d ago"
    } else {
      $dt | format date "%Y-%m-%d"
    }
  } catch {
    $timestamp
  }
}

# =============================================================================
# Workflow Formatters
# =============================================================================

# Format a list of workflows
export def format-workflow-list [workflows: list] {
  if ($workflows | length) == 0 {
    return "No workflows found."
  }

  let header = "Workflows:"
  let lines = $workflows | each {|wf|
      let state = format-workflow-state ($wf.state? | default "unknown")
      $"  - ($wf.name) [($state)] - ($wf.path)"
    }

  [$header] | append $lines | str join (char newline)
}

# Format a list of workflow runs
export def format-workflow-runs [runs: list] {
  if ($runs | length) == 0 {
    return "No workflow runs found."
  }

  let header = "Recent Workflow Runs:"
  let lines = $runs | each {|run|
      let status = format-run-status ($run.status? | default "") ($run.conclusion? | default "")
      let time = format-relative-time ($run.createdAt? | default "")
      let branch = $run.headBranch? | default "unknown"
      let title = $run.displayTitle? | default ($run.workflowName? | default "unknown")
      $"  - #($run.databaseId) ($title) [($status)] on ($branch) (($time))"
    }

  [$header] | append $lines | str join (char newline)
}

# Format a single workflow run with details
export def format-workflow-run [run: record] {
  let status = format-run-status ($run.status? | default "") ($run.conclusion? | default "")
  let time = format-relative-time ($run.createdAt? | default "")

  mut lines = [
    $"Workflow Run #($run.databaseId)"
    $"  Name: ($run.displayTitle? | default 'N/A')"
    $"  Workflow: ($run.workflowName? | default 'N/A')"
    $"  Status: ($status)"
    $"  Branch: ($run.headBranch? | default 'N/A')"
    $"  Commit: ($run.headSha? | default 'N/A' | str substring 0..7)"
    $"  Event: ($run.event? | default 'N/A')"
    $"  Started: ($time)"
  ]

  if "url" in $run {
    $lines = ($lines | append $"  URL: ($run.url)")
  }

  # Format jobs if present
  if "jobs" in $run and ($run.jobs | length) > 0 {
    $lines = ($lines | append "" | append "  Jobs:")
    for job in $run.jobs {
      let job_status = format-run-status ($job.status? | default "") ($job.conclusion? | default "")
      $lines = ($lines | append $"    - ($job.name? | default 'unknown') [($job_status)]")
    }
  }

  $lines | str join (char newline)
}

# =============================================================================
# PR Formatters
# =============================================================================

# Format a list of pull requests
export def format-pr-list [prs: list] {
  if ($prs | length) == 0 {
    return "No pull requests found."
  }

  let header = "Pull Requests:"
  let lines = $prs | each {|pr|
      let state = format-pr-state ($pr.state? | default "OPEN") ($pr.isDraft? | default false)
      let author = $pr.author?.login? | default "unknown"
      let time = format-relative-time ($pr.createdAt? | default "")
      $"  - #($pr.number) ($pr.title) [($state)] by ($author) (($time))"
    }

  [$header] | append $lines | str join (char newline)
}

# Format a single PR with details
export def format-pr [pr: record] {
  let state = format-pr-state ($pr.state? | default "OPEN") ($pr.isDraft? | default false)
  let author = $pr.author?.login? | default "unknown"
  let created = format-relative-time ($pr.createdAt? | default "")
  let updated = format-relative-time ($pr.updatedAt? | default "")

  mut lines = [
    $"Pull Request #($pr.number)"
    $"  Title: ($pr.title? | default 'N/A')"
    $"  State: ($state)"
    $"  Author: ($author)"
    $"  Branch: ($pr.headRefName? | default 'N/A') -> ($pr.baseRefName? | default 'N/A')"
    $"  Created: ($created)"
    $"  Updated: ($updated)"
  ]

  # Add labels if present
  if "labels" in $pr and ($pr.labels | length) > 0 {
    let label_names = $pr.labels | each {|l| $l.name? | default "" } | where {|n| $n != "" }
    if ($label_names | length) > 0 {
      $lines = ($lines | append $"  Labels: ($label_names | str join ', ')")
    }
  }

  # Add reviewers if present
  if "reviewRequests" in $pr and ($pr.reviewRequests | length) > 0 {
    let reviewers = $pr.reviewRequests | each {|r|
        $r.requestedReviewer?.login? | default ($r.requestedReviewer?.name? | default "")
      } | where {|n| $n != "" }
    if ($reviewers | length) > 0 {
      $lines = ($lines | append $"  Reviewers: ($reviewers | str join ', ')")
    }
  }

  if "url" in $pr {
    $lines = ($lines | append $"  URL: ($pr.url)")
  }

  # Add body if present (truncated)
  if "body" in $pr and $pr.body != null and ($pr.body | str length) > 0 {
    let body = if ($pr.body | str length) > 200 {
      ($pr.body | str substring 0..200) + "..."
    } else {
      $pr.body
    }
    $lines = ($lines | append "" | append "  Description:" | append $"    ($body)")
  }

  $lines | str join (char newline)
}

# Format PR checks
export def format-pr-checks [checks: list pr_number: int] {
  if ($checks | length) == 0 {
    return $"No checks found for PR #($pr_number)."
  }

  let header = $"Checks for PR #($pr_number):"

  let lines = $checks | each {|check|
      let status = format-check-state ($check.state? | default "") ($check.conclusion? | default "")
      $"  - ($check.name) [($status)]"
    }

  # Summary
  let get_status = {|c| if ($c.conclusion? | default "") != "" { $c.conclusion } else { $c.state? | default "" } | str downcase }
  let passed = $checks | where {|c| (do $get_status $c) == "success" } | length
  let failed = $checks | where {|c| (do $get_status $c) == "failure" } | length
  let pending = $checks | where {|c| (do $get_status $c) == "pending" } | length
  let total = $checks | length

  let summary = $"Summary: ($passed)/($total) passed" + (if $failed > 0 { $", ($failed) failed" } else { "" }) + (if $pending > 0 { $", ($pending) pending" } else { "" })

  [$header] | append $lines | append "" | append $summary | str join (char newline)
}

# =============================================================================
# Result Formatters
# =============================================================================

# Format upsert PR result
export def format-upsert-result [result: record action: string] {
  let action_text = if $action == "created" { "Created" } else { "Updated" }
  $"($action_text) PR #($result.number? | default 'N/A')
URL: ($result.url? | default 'N/A')"
}

# Format run workflow result
export def format-run-workflow-result [result: record] {
  let success = ($result.success? | default false)
  if $success {
    let workflow = ($result.workflow? | default "N/A")
    let message = ($result.message? | default "")
    $"Triggered workflow: ($workflow)($message)"
  } else {
    let message = ($result.message? | default "unknown error")
    $"Failed to trigger workflow: ($message)"
  }
}

# =============================================================================
# Release Formatters
# =============================================================================

# Format release state with indicators
def format-release-state [is_draft: bool is_prerelease: bool is_latest: bool] {
  mut badges = []

  if $is_draft {
    $badges = ($badges | append "draft")
  }

  if $is_prerelease {
    $badges = ($badges | append "prerelease")
  }

  if $is_latest {
    $badges = ($badges | append "latest")
  }

  if ($badges | length) > 0 {
    $badges | str join ", "
  } else {
    "release"
  }
}

# Format a list of releases
export def format-release-list [releases: list] {
  if ($releases | length) == 0 {
    return "No releases found."
  }

  let header = "Releases:"
  let lines = $releases | each {|rel|
      let state = format-release-state ($rel.isDraft? | default false) ($rel.isPrerelease? | default false) ($rel.isLatest? | default false)
      let time = format-relative-time ($rel.publishedAt? | default ($rel.createdAt? | default ""))
      let name = $rel.name? | default $rel.tagName
      $"  - ($rel.tagName) ($name) [($state)] (($time))"
    }

  [$header] | append $lines | str join (char newline)
}

# Format a single release with details
export def format-release [release: record] {
  let state = format-release-state ($release.isDraft? | default false) ($release.isPrerelease? | default false) false
  let author = $release.author?.login? | default "unknown"
  let created = format-relative-time ($release.createdAt? | default "")

  mut lines = [
    $"Release ($release.name? | default $release.tagName)"
    $"  Tag: ($release.tagName? | default 'N/A')"
    $"  Status: ($state)"
    $"  Author: ($author)"
    $"  Created: ($created)"
  ]

  # Add published date if not a draft
  if not ($release.isDraft? | default false) and "publishedAt" in $release and $release.publishedAt != null {
    let published = format-relative-time $release.publishedAt
    $lines = ($lines | append $"  Published: ($published)")
  }

  # Add assets count if present
  if "assets" in $release and ($release.assets | length) > 0 {
    $lines = ($lines | append $"  Assets: ($release.assets | length) assets")
  }

  if "url" in $release {
    $lines = ($lines | append $"  URL: ($release.url)")
  }

  # Add body if present (truncated)
  if "body" in $release and $release.body != null and ($release.body | str length) > 0 {
    let body = if ($release.body | str length) > 300 {
      ($release.body | str substring 0..300) + "..."
    } else {
      $release.body
    }
    $lines = ($lines | append "" | append "  Description:" | append $"    ($body)")
  }

  $lines | str join (char newline)
}
