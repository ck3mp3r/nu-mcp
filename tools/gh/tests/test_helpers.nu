# Test helper functions for GitHub tool tests

# Helper to create mock data for successful responses
export def mock-success [output: string] {
  {exit_code: 0 output: $output} | to json
}

# Helper to create mock data for error responses
export def mock-error [error: string exit_code: int = 1] {
  {exit_code: $exit_code error: $error output: ""} | to json
}

# Assert that two values are equal
export def assert-eq [actual: any expected: any message: string = ""] {
  if $actual != $expected {
    let msg = if $message != "" {
      $"Assertion failed: ($message)\n  Expected: ($expected)\n  Actual: ($actual)"
    } else {
      $"Assertion failed:\n  Expected: ($expected)\n  Actual: ($actual)"
    }
    error make {msg: $msg}
  }
}

# Assert that a value is true
export def assert-true [value: bool message: string = "Expected true"] {
  if not $value {
    error make {msg: $"Assertion failed: ($message)"}
  }
}

# Assert that a value is false
export def assert-false [value: bool message: string = "Expected false"] {
  if $value {
    error make {msg: $"Assertion failed: ($message)"}
  }
}

# Assert that a closure throws an error
export def assert-error [test_fn: closure expected_msg: string = ""] {
  let result = try {
    do $test_fn
    {threw: false error: null}
  } catch {|err|
    {threw: true error: $err.msg}
  }

  if not $result.threw {
    error make {msg: "Expected error but none was thrown"}
  }

  if $expected_msg != "" and not ($result.error | str contains $expected_msg) {
    error make {msg: $"Expected error containing '($expected_msg)' but got: ($result.error)"}
  }
}

# Assert that a list contains an item
export def assert-contains [list: list item: any message: string = ""] {
  if $item not-in $list {
    let msg = if $message != "" {
      $"Assertion failed: ($message)\n  List does not contain: ($item)"
    } else {
      $"Assertion failed: List does not contain: ($item)"
    }
    error make {msg: $msg}
  }
}

# Assert that a record has a key
export def assert-has-key [rec: record key: string message: string = ""] {
  if $key not-in $rec {
    let msg = if $message != "" {
      $"Assertion failed: ($message)\n  Record does not have key: ($key)"
    } else {
      $"Assertion failed: Record does not have key: ($key)"
    }
    error make {msg: $msg}
  }
}

# Assert that a string contains a substring
export def assert-str-contains [haystack: string needle: string message: string = ""] {
  if not ($haystack | str contains $needle) {
    let msg = if $message != "" {
      $"Assertion failed: ($message)\n  String does not contain: ($needle)"
    } else {
      $"Assertion failed: String does not contain: ($needle)"
    }
    error make {msg: $msg}
  }
}

# Sample mock data for workflows
export def sample-workflow-list [] {
  [
    {id: 12345678 name: "CI" path: ".github/workflows/ci.yaml" state: "active"}
    {id: 87654321 name: "Release" path: ".github/workflows/release.yaml" state: "active"}
  ] | to json
}

# Sample mock data for workflow runs
export def sample-workflow-runs [] {
  [
    {
      databaseId: 11111
      displayTitle: "Fix bug in parser"
      status: "completed"
      conclusion: "success"
      workflowName: "CI"
      headBranch: "main"
      event: "push"
      createdAt: "2025-01-15T10:00:00Z"
    }
    {
      databaseId: 22222
      displayTitle: "Add new feature"
      status: "in_progress"
      conclusion: null
      workflowName: "CI"
      headBranch: "feature/new-feature"
      event: "pull_request"
      createdAt: "2025-01-15T11:00:00Z"
    }
  ] | to json
}

# Sample mock data for a single workflow run
export def sample-workflow-run [] {
  {
    databaseId: 11111
    displayTitle: "Fix bug in parser"
    status: "completed"
    conclusion: "success"
    workflowName: "CI"
    headBranch: "main"
    headSha: "abc123def456"
    event: "push"
    createdAt: "2025-01-15T10:00:00Z"
    updatedAt: "2025-01-15T10:05:00Z"
    url: "https://github.com/owner/repo/actions/runs/11111"
    jobs: [
      {name: "build" status: "completed" conclusion: "success"}
      {name: "test" status: "completed" conclusion: "success"}
    ]
  } | to json
}

# Sample mock data for PRs
export def sample-pr-list [] {
  [
    {
      number: 42
      title: "Add new feature"
      state: "OPEN"
      author: {login: "developer"}
      headRefName: "feature/new-feature"
      baseRefName: "main"
      createdAt: "2025-01-10T10:00:00Z"
      isDraft: false
    }
    {
      number: 41
      title: "Fix documentation"
      state: "MERGED"
      author: {login: "contributor"}
      headRefName: "docs/fix-typo"
      baseRefName: "main"
      createdAt: "2025-01-09T10:00:00Z"
      isDraft: false
    }
  ] | to json
}

# Sample mock data for a single PR
export def sample-pr [] {
  {
    number: 42
    title: "Add new feature"
    body: "This PR adds a great new feature.\n\n## Changes\n- Added feature X\n- Updated docs"
    state: "OPEN"
    author: {login: "developer"}
    headRefName: "feature/new-feature"
    baseRefName: "main"
    createdAt: "2025-01-10T10:00:00Z"
    updatedAt: "2025-01-14T15:30:00Z"
    isDraft: false
    labels: [{name: "enhancement"} {name: "needs-review"}]
    reviewRequests: [{login: "reviewer1"} {login: "reviewer2"}]
    url: "https://github.com/owner/repo/pull/42"
  } | to json
}

# Sample mock data for PR checks
export def sample-pr-checks [] {
  [
    {name: "CI / build" state: "SUCCESS" bucket: "pass" workflow: "CI" completedAt: "2024-01-15T10:00:00Z"}
    {name: "CI / test" state: "SUCCESS" bucket: "pass" workflow: "CI" completedAt: "2024-01-15T10:05:00Z"}
    {name: "lint" state: "SUCCESS" bucket: "pass" workflow: "Lint" completedAt: "2024-01-15T10:02:00Z"}
  ] | to json
}

# Sample mock data for releases list
export def sample-release-list [] {
  [
    {
      tagName: "v1.0.0"
      name: "Release v1.0.0"
      isDraft: false
      isPrerelease: false
      isLatest: true
      createdAt: "2025-01-15T10:00:00Z"
      publishedAt: "2025-01-15T10:05:00Z"
    }
    {
      tagName: "v0.9.0"
      name: "Beta Release v0.9.0"
      isDraft: false
      isPrerelease: true
      isLatest: false
      createdAt: "2025-01-10T10:00:00Z"
      publishedAt: "2025-01-10T10:05:00Z"
    }
    {
      tagName: "v0.8.0"
      name: "Draft Release v0.8.0"
      isDraft: true
      isPrerelease: false
      isLatest: false
      createdAt: "2025-01-05T10:00:00Z"
      publishedAt: null
    }
  ] | to json
}

# Sample mock data for a single release
export def sample-release [] {
  {
    tagName: "v1.0.0"
    name: "Release v1.0.0"
    body: "## What's Changed\n- New feature X\n- Bug fix Y"
    isDraft: false
    isPrerelease: false
    createdAt: "2025-01-15T10:00:00Z"
    publishedAt: "2025-01-15T10:05:00Z"
    author: {login: "maintainer"}
    url: "https://github.com/owner/repo/releases/tag/v1.0.0"
    assets: [
      {name: "binary-linux.tar.gz" size: 1234567}
      {name: "binary-macos.tar.gz" size: 1234568}
    ]
  } | to json
}
