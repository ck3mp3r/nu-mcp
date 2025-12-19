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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu list-prs
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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu list-prs
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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu list-prs
      list-prs --state open
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return PRs"
}

export def "test list-prs with author filter" [] {
  let mock_output = sample-pr-list
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft___author_developer: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu list-prs
      list-prs --author developer
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return PRs"
}

export def "test list-prs with limit" [] {
  let mock_output = sample-pr-list
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft___limit_10: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu list-prs
      list-prs --limit 10
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return PRs"
}

export def "test list-prs handles error" [] {
  let result = with-env {MOCK_gh_pr_list___json_number_title_state_author_headRefName_baseRefName_createdAt_isDraft: (mock-error "not a git repository")} {
    do {
      nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu list-prs
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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu get-pr
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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu get-pr
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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu get-pr-checks
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
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu get-pr-checks
      get-pr-checks 999
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
}

# =============================================================================
# create-pr tests (destructive - needs safety mode)
# =============================================================================

export def "test create-pr blocked in readonly mode" [] {
  let result = with-env {MCP_GITHUB_MODE: "readonly"} {
    do {
      nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu create-pr
      create-pr 'Test PR'
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "destructive mode") "Should mention destructive mode"
}

export def "test create-pr allowed in destructive mode" [] {
  let mock_output = '{"number": 43, "url": "https://github.com/owner/repo/pull/43"}'
  let result = with-env {MCP_GITHUB_MODE: "destructive" MOCK_gh_pr_create___title_Test_PR___json_number_url: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu create-pr
      create-pr 'Test PR'
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 43) "Should return new PR number"
}

export def "test create-pr with body and base" [] {
  let mock_output = '{"number": 44, "url": "https://github.com/owner/repo/pull/44"}'
  let result = with-env {
    MCP_GITHUB_MODE: "destructive"
    MOCK_gh_pr_create___title_Feature___body_Description___base_develop___json_number_url: (mock-success $mock_output)
  } {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu create-pr
      create-pr 'Feature' --body 'Description' --base develop
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 44) "Should return new PR number"
}

export def "test create-pr as draft" [] {
  let mock_output = '{"number": 45, "url": "https://github.com/owner/repo/pull/45"}'
  let result = with-env {
    MCP_GITHUB_MODE: "destructive"
    MOCK_gh_pr_create___title_Draft_PR___draft___json_number_url: (mock-success $mock_output)
  } {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu create-pr
      create-pr 'Draft PR' --draft
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 45) "Should return new PR number"
}

# =============================================================================
# update-pr tests (destructive - needs safety mode)
# =============================================================================

export def "test update-pr blocked in readonly mode" [] {
  let result = with-env {MCP_GITHUB_MODE: "readonly"} {
    do {
      nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu update-pr
      update-pr 42 --title 'New Title'
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "destructive mode") "Should mention destructive mode"
}

export def "test update-pr title" [] {
  let mock_output = '{"number": 42, "url": "https://github.com/owner/repo/pull/42"}'
  let result = with-env {
    MCP_GITHUB_MODE: "destructive"
    MOCK_gh_pr_edit_42___title_New_Title___json_number_url: (mock-success $mock_output)
  } {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu update-pr
      update-pr 42 --title 'New Title'
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return PR number"
}

export def "test update-pr add labels" [] {
  let mock_output = '{"number": 42, "url": "https://github.com/owner/repo/pull/42"}'
  let result = with-env {
    MCP_GITHUB_MODE: "destructive"
    MOCK_gh_pr_edit_42___add_label_bug___json_number_url: (mock-success $mock_output)
  } {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu update-pr
      update-pr 42 --add-labels [bug]
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return PR number"
}

export def "test update-pr add reviewers" [] {
  let mock_output = '{"number": 42, "url": "https://github.com/owner/repo/pull/42"}'
  let result = with-env {
    MCP_GITHUB_MODE: "destructive"
    MOCK_gh_pr_edit_42___add_reviewer_reviewer1___json_number_url: (mock-success $mock_output)
  } {
    nu --no-config-file -c "
      use tools/github/tests/mocks.nu *
      use tools/github/prs.nu update-pr
      update-pr 42 --add-reviewers [reviewer1]
    "
  }
  let parsed = $result | from json

  assert (($parsed | get number) == 42) "Should return PR number"
}
