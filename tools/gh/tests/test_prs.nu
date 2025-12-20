# Tests for GitHub PR tools
# Mocks must be imported BEFORE the module under test

use std/assert
use test_helpers.nu [ sample-pr-list sample-pr sample-pr-checks ]

# Helper to create mock JSON for success
def mock-success [output: string] {
  {exit_code: 0 output: $output} | to json
}

# Helper to create mock JSON for error
def mock-error [error: string] {
  {exit_code: 1 error: $error output: ""} | to json
}

# =============================================================================
# list-prs tests
# =============================================================================

export def "test list-prs returns pr list" [] {
  let mock_output = sample-pr-list
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu list-prs
      list-prs
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return 2 PRs"
  assert (($parsed | get 0 | get number) == 42) "First PR should be #42"
  assert (($parsed | get 0 | get title) == "Add new feature") "First PR title"
}

export def "test list-prs with empty result" [] {
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft: (mock-success "[]")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu list-prs
      list-prs
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 0) "Should return empty list"
}

export def "test list-prs with state filter" [] {
  let mock_output = sample-pr-list
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft___state_open: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu list-prs
      list-prs --state open
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return PRs"
}

export def "test list-prs handles error" [] {
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft: (mock-error "not a git repository")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu list-prs
      list-prs
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "not a git repository") "Should contain error"
}

# =============================================================================
# get-pr tests
# =============================================================================

export def "test get-pr returns pr details" [] {
  let mock_output = sample-pr
  let result = with-env {MOCK_gh_pr_view_42___json_number_title_body_state_author_headRefName_baseRefName_createdAt_updatedAt_isDraft_labels_reviewRequests_url: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu get-pr
      get-pr 42
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return PR #42"
  assert (($parsed | get title) == "Add new feature") "Should return correct title"
  assert (($parsed | get labels | length) == 2) "Should have 2 labels"
}

export def "test get-pr handles not found" [] {
  let result = with-env {MOCK_gh_pr_view_999___json_number_title_body_state_author_headRefName_baseRefName_createdAt_updatedAt_isDraft_labels_reviewRequests_url: (mock-error "Could not resolve to a PullRequest")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu get-pr
      get-pr 999
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "PullRequest") "Should contain error"
}

# =============================================================================
# get-pr-checks tests
# =============================================================================

export def "test get-pr-checks returns checks" [] {
  let mock_output = sample-pr-checks
  let result = with-env {MOCK_gh_pr_checks_42___json_name_state_conclusion: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu get-pr-checks
      get-pr-checks 42
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 3) "Should return 3 checks"
  assert (($parsed | get 0 | get name) == "CI / build") "First check name"
  assert (($parsed | get 0 | get state) == "SUCCESS") "First check state"
}

export def "test get-pr-checks handles error" [] {
  let result = with-env {MOCK_gh_pr_checks_999___json_name_state_conclusion: (mock-error "Could not resolve to a PullRequest")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu get-pr-checks
      get-pr-checks 999
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
}

# =============================================================================
# upsert-pr tests (destructive - needs safety mode)
# =============================================================================

export def "test upsert-pr blocked in readonly mode" [] {
  let result = with-env {MCP_GITHUB_MODE: "readonly"} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu upsert-pr
      upsert-pr 'Test PR' --head feature-branch
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "readwrite mode") "Should mention readwrite mode"
}

export def "test upsert-pr creates new pr when none exists" [] {
  # First: check for existing PR by head branch - returns empty (no PR)
  # Then: create new PR (returns URL to stdout)
  let mock_url = "https://github.com/owner/repo/pull/43"
  let result = with-env {
    MOCK_gh_pr_list___head_feature_branch___json_number_headRefName: (mock-success "[]")
    MOCK_gh_pr_create___title_Test_PR___head_feature_branch: (mock-success $mock_url)
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu upsert-pr
      upsert-pr 'Test PR' --head feature-branch
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 43) "Should return new PR number"
  assert (($parsed | get url) == $mock_url) "Should return PR URL"
}

export def "test upsert-pr updates existing pr" [] {
  # First: check for existing PR - returns PR #42
  # Then: update it with new title (edit doesn't return anything)
  # Then: get the PR details
  let existing_pr = '[{"number": 42, "headRefName": "feature-branch"}]'
  let pr_details = (sample-pr)
  let result = with-env {
    MOCK_gh_pr_list___head_feature_branch___json_number_headRefName: (mock-success $existing_pr)
    MOCK_gh_pr_edit_42___title_Updated_Title: (mock-success "")
    MOCK_gh_pr_view_42___json_number_title_body_state_author_headRefName_baseRefName_createdAt_updatedAt_isDraft_labels_reviewRequests_url: (mock-success $pr_details)
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu upsert-pr
      upsert-pr 'Updated Title' --head feature-branch
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return existing PR number"
}

export def "test upsert-pr with body and labels creates new" [] {
  let mock_url = "https://github.com/owner/repo/pull/44"
  let result = with-env {
    MOCK_gh_pr_list___head_my_branch___json_number_headRefName: (mock-success "[]")
    MOCK_gh_pr_create___title_New_Feature___head_my_branch___body_Description___label_enhancement: (mock-success $mock_url)
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu upsert-pr
      upsert-pr 'New Feature' --head my-branch --body Description --labels [enhancement]
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 44) "Should return new PR number"
  assert (($parsed | get url) == $mock_url) "Should return PR URL"
}

export def "test upsert-pr uses current branch when head not specified" [] {
  # When no --head, get current branch from git, then check/create
  let mock_url = "https://github.com/owner/repo/pull/45"
  let result = with-env {
    MOCK_git_branch___show_current: (mock-success "current-feature")
    MOCK_gh_pr_list___head_current_feature___json_number_headRefName: (mock-success "[]")
    MOCK_gh_pr_create___title_My_PR___head_current_feature: (mock-success $mock_url)
  } {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/prs.nu upsert-pr
      upsert-pr 'My PR'
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 45) "Should return new PR number"
  assert (($parsed | get url) == $mock_url) "Should return PR URL"
}
