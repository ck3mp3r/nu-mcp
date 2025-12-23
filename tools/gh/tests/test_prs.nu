# Tests for GitHub PR tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mock *
use test_helpers.nu [ sample-pr-list sample-pr sample-pr-checks ]
use wrappers.nu *

# =============================================================================
# list-prs tests
# =============================================================================

export def --env "test list-prs returns pr list" [] {
  mock reset

  let mock_output = sample-pr-list
  mock register gh {
    args: ['pr' 'list' '--json' 'number,title,state,author,headRefName,baseRefName,createdAt,isDraft']
    returns: $mock_output
  }

  use ../prs.nu list-prs
  let result = list-prs
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return 2 PRs"
  assert (($parsed | get 0 | get number) == 42) "First PR should be #42"
  assert (($parsed | get 0 | get title) == "Add new feature") "First PR title"

  mock verify
}

export def --env "test list-prs with empty result" [] {
  mock reset

  mock register gh {
    args: ['pr' 'list' '--json' 'number,title,state,author,headRefName,baseRefName,createdAt,isDraft']
    returns: "[]"
  }

  use ../prs.nu list-prs
  let result = list-prs
  let parsed = $result | from json

  assert (($parsed | length) == 0) "Should return empty list"

  mock verify
}

export def --env "test list-prs with state filter" [] {
  mock reset

  let mock_output = sample-pr-list
  mock register gh {
    args: ['pr' 'list' '--json' 'number,title,state,author,headRefName,baseRefName,createdAt,isDraft' '--state' 'open']
    returns: $mock_output
  }

  use ../prs.nu list-prs
  let result = list-prs --state open
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return PRs"

  mock verify
}

export def --env "test list-prs handles error" [] {
  mock reset

  mock register gh {
    args: ['pr' 'list' '--json' 'number,title,state,author,headRefName,baseRefName,createdAt,isDraft']
    returns: "not a git repository"
    exit_code: 1
  }

  use ../prs.nu list-prs
  let result = try {
    list-prs
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "not a git repository") "Should contain error"

  mock verify
}

# =============================================================================
# get-pr tests
# =============================================================================

export def --env "test get-pr returns pr details" [] {
  mock reset

  let mock_output = sample-pr
  mock register gh {
    args: ['pr' 'view' '42' '--json' 'number,title,body,state,author,headRefName,baseRefName,createdAt,updatedAt,isDraft,labels,reviewRequests,url']
    returns: $mock_output
  }

  use ../prs.nu get-pr
  let result = get-pr 42
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return PR #42"
  assert (($parsed | get title) == "Add new feature") "Should return correct title"
  assert (($parsed | get labels | length) == 2) "Should have 2 labels"

  mock verify
}

export def --env "test get-pr handles not found" [] {
  mock reset

  mock register gh {
    args: ['pr' 'view' '999' '--json' 'number,title,body,state,author,headRefName,baseRefName,createdAt,updatedAt,isDraft,labels,reviewRequests,url']
    returns: "Could not resolve to a PullRequest"
    exit_code: 1
  }

  use ../prs.nu get-pr
  let result = try {
    get-pr 999
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "PullRequest") "Should contain error"

  mock verify
}

# =============================================================================
# get-pr-checks tests
# =============================================================================

export def --env "test get-pr-checks returns checks" [] {
  mock reset

  let mock_output = sample-pr-checks
  mock register gh {
    args: ['pr' 'checks' '42' '--json' 'name,state,bucket,workflow,completedAt']
    returns: $mock_output
  }

  use ../prs.nu get-pr-checks
  let result = get-pr-checks 42
  let parsed = $result | from json

  assert (($parsed | length) == 3) "Should return 3 checks"
  assert (($parsed | get 0 | get name) == "CI / build") "First check name"
  assert (($parsed | get 0 | get state) == "SUCCESS") "First check state"

  mock verify
}

export def --env "test get-pr-checks handles error" [] {
  mock reset

  mock register gh {
    args: ['pr' 'checks' '999' '--json' 'name,state,bucket,workflow,completedAt']
    returns: "Could not resolve to a PullRequest"
    exit_code: 1
  }

  use ../prs.nu get-pr-checks
  let result = try {
    get-pr-checks 999
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"

  mock verify
}

# =============================================================================
# upsert-pr tests (destructive - needs safety mode)
# =============================================================================

export def --env "test upsert-pr blocked in readonly mode" [] {
  mock reset
  $env.MCP_GITHUB_MODE = "readonly"

  use ../prs.nu upsert-pr
  let result = try {
    upsert-pr 'Test PR' --head feature-branch
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "readwrite mode") "Should mention readwrite mode"

  mock verify
}

export def --env "test upsert-pr creates new pr when none exists" [] {
  mock reset

  # First: check for existing PR by head branch - returns empty (no PR)
  mock register gh {
    args: ['pr' 'list' '--head' 'feature-branch' '--json' 'number,headRefName']
    returns: "[]"
  }

  # Then: create new PR (returns URL to stdout)
  let mock_url = "https://github.com/owner/repo/pull/43"
  mock register gh {
    args: ['pr' 'create' '--title' 'Test PR' '--head' 'feature-branch']
    returns: $mock_url
  }

  use ../prs.nu upsert-pr
  let result = upsert-pr 'Test PR' --head feature-branch
  let parsed = $result | from json

  assert (($parsed | get number) == 43) "Should return new PR number"
  assert (($parsed | get url) == $mock_url) "Should return PR URL"

  mock verify
}

export def --env "test upsert-pr updates existing pr" [] {
  mock reset

  # First: check for existing PR - returns PR #42
  let existing_pr = '[{"number": 42, "headRefName": "feature-branch"}]'
  mock register gh {
    args: ['pr' 'list' '--head' 'feature-branch' '--json' 'number,headRefName']
    returns: $existing_pr
  }

  # Then: update it with new title (edit doesn't return anything)
  mock register gh {
    args: ['pr' 'edit' '42' '--title' 'Updated Title']
    returns: ""
  }

  # Then: get the PR details
  let pr_details = (sample-pr)
  mock register gh {
    args: ['pr' 'view' '42' '--json' 'number,title,body,state,author,headRefName,baseRefName,createdAt,updatedAt,isDraft,labels,reviewRequests,url']
    returns: $pr_details
  }

  use ../prs.nu upsert-pr
  let result = upsert-pr 'Updated Title' --head feature-branch
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return existing PR number"

  mock verify
}

export def --env "test upsert-pr with body and labels creates new" [] {
  mock reset

  # Check for existing PR - none found
  mock register gh {
    args: ['pr' 'list' '--head' 'my-branch' '--json' 'number,headRefName']
    returns: "[]"
  }

  # Create new PR with body and label
  let mock_url = "https://github.com/owner/repo/pull/44"
  mock register gh {
    args: ['pr' 'create' '--title' 'New Feature' '--head' 'my-branch' '--body' 'Description' '--label' 'enhancement']
    returns: $mock_url
  }

  use ../prs.nu upsert-pr
  let result = upsert-pr 'New Feature' --head my-branch --body Description --labels [enhancement]
  let parsed = $result | from json

  assert (($parsed | get number) == 44) "Should return new PR number"
  assert (($parsed | get url) == $mock_url) "Should return PR URL"

  mock verify
}

export def --env "test upsert-pr uses current branch when head not specified" [] {
  mock reset

  # When no --head, get current branch from git
  mock register git {
    args: ['branch' '--show-current']
    returns: "current-feature"
  }

  # Check for existing PR - none found
  mock register gh {
    args: ['pr' 'list' '--head' 'current-feature' '--json' 'number,headRefName']
    returns: "[]"
  }

  # Create new PR
  let mock_url = "https://github.com/owner/repo/pull/45"
  mock register gh {
    args: ['pr' 'create' '--title' 'My PR' '--head' 'current-feature']
    returns: $mock_url
  }

  use ../prs.nu upsert-pr
  let result = upsert-pr 'My PR'
  let parsed = $result | from json

  assert (($parsed | get number) == 45) "Should return new PR number"
  assert (($parsed | get url) == $mock_url) "Should return PR URL"

  mock verify
}

# =============================================================================
# close-pr tests
# =============================================================================

export def --env "test close-pr closes pr successfully" [] {
  mock reset

  mock register gh {
    args: ['pr' 'close' '42']
    returns: ""
  }

  use ../prs.nu close-pr
  let result = close-pr 42
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"
  assert (($parsed.message | str contains "42") and ($parsed.message | str contains "closed")) "Should mention PR number and closed"

  mock verify
}

export def --env "test close-pr with comment" [] {
  mock reset

  mock register gh {
    args: ['pr' 'close' '42' '--comment' 'Closing this']
    returns: ""
  }

  use ../prs.nu close-pr
  let result = close-pr 42 --comment 'Closing this'
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"

  mock verify
}

export def --env "test close-pr with delete branch" [] {
  mock reset

  mock register gh {
    args: ['pr' 'close' '42' '--delete-branch']
    returns: ""
  }

  use ../prs.nu close-pr
  let result = close-pr 42 --delete-branch
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"

  mock verify
}

# =============================================================================
# reopen-pr tests
# =============================================================================

export def --env "test reopen-pr reopens pr successfully" [] {
  mock reset

  mock register gh {
    args: ['pr' 'reopen' '42']
    returns: ""
  }

  use ../prs.nu reopen-pr
  let result = reopen-pr 42
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"
  assert (($parsed.message | str contains "42") and ($parsed.message | str contains "reopened")) "Should mention PR number and reopened"

  mock verify
}

export def --env "test reopen-pr with comment" [] {
  mock reset

  mock register gh {
    args: ['pr' 'reopen' '42' '--comment' 'Reopening']
    returns: ""
  }

  use ../prs.nu reopen-pr
  let result = reopen-pr 42 --comment 'Reopening'
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"

  mock verify
}

# =============================================================================
# merge-pr tests
# =============================================================================

export def --env "test merge-pr fails without confirm-merge" [] {
  mock reset

  use ../prs.nu merge-pr
  let result = try {
    merge-pr 42
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "explicit confirmation") "Should mention confirmation required"

  mock verify
}

export def --env "test merge-pr succeeds with confirm-merge true" [] {
  mock reset

  mock register gh {
    args: ['pr' 'merge' '42' '--squash']
    returns: ""
  }

  use ../prs.nu merge-pr
  let result = merge-pr 42 --confirm-merge
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"
  assert (($parsed.message | str contains "42") and ($parsed.message | str contains "merged")) "Should mention PR number and merged"
  assert ($parsed.message | str contains "squash") "Should mention squash strategy (default)"

  mock verify
}

export def --env "test merge-pr with merge strategy" [] {
  mock reset

  mock register gh {
    args: ['pr' 'merge' '42' '--merge']
    returns: ""
  }

  use ../prs.nu merge-pr
  let result = merge-pr 42 --confirm-merge --merge
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"
  assert ($parsed.message | str contains "merge") "Should mention merge strategy"

  mock verify
}

export def --env "test merge-pr with rebase strategy" [] {
  mock reset

  mock register gh {
    args: ['pr' 'merge' '42' '--rebase']
    returns: ""
  }

  use ../prs.nu merge-pr
  let result = merge-pr 42 --confirm-merge --rebase
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"
  assert ($parsed.message | str contains "rebase") "Should mention rebase strategy"

  mock verify
}

export def --env "test merge-pr with delete branch" [] {
  mock reset

  mock register gh {
    args: ['pr' 'merge' '42' '--squash' '--delete-branch']
    returns: ""
  }

  use ../prs.nu merge-pr
  let result = merge-pr 42 --confirm-merge --delete-branch
  let parsed = $result | from json

  assert ($parsed.success == true) "Should succeed"

  mock verify
}
