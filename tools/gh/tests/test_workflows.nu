# Tests for GitHub workflow tools
# Mocks must be imported BEFORE the module under test

use std/assert
use test_helpers.nu [ sample-workflow-list sample-workflow-runs sample-workflow-run ]

# Helper to create mock JSON for success
def mock-success [output: string] {
  {exit_code: 0 output: $output} | to json
}

# Helper to create mock JSON for error
def mock-error [error: string] {
  {exit_code: 1 error: $error output: ""} | to json
}

# =============================================================================
# list-workflows tests
# =============================================================================

export def "test list-workflows returns workflow list" [] {
  let mock_output = sample-workflow-list
  # Key: workflow_list___json_id_name_path_state (commas replaced with _)
  let result = with-env {MOCK_gh_workflow_list___json_id_name_path_state: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflows
      list-workflows
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return 2 workflows"
  assert (($parsed | get 0 | get name) == "CI") "First workflow should be CI"
}

export def "test list-workflows with empty result" [] {
  let result = with-env {MOCK_gh_workflow_list___json_id_name_path_state: (mock-success "[]")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflows
      list-workflows
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 0) "Should return empty list"
}

export def "test list-workflows handles gh error" [] {
  let result = with-env {MOCK_gh_workflow_list___json_id_name_path_state: (mock-error "not a git repository")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflows
      list-workflows
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "not a git repository") "Should contain error message"
}

# =============================================================================
# list-workflow-runs tests
# =============================================================================

export def "test list-workflow-runs returns runs" [] {
  let mock_output = sample-workflow-runs
  let result = with-env {MOCK_gh_run_list___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_event_createdAt: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflow-runs
      list-workflow-runs
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return 2 runs"
  assert (($parsed | get 0 | get status) == "completed") "First run should be completed"
}

export def "test list-workflow-runs with limit" [] {
  let mock_output = sample-workflow-runs
  let result = with-env {MOCK_gh_run_list___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_event_createdAt___limit_5: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflow-runs
      list-workflow-runs --limit 5
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"
}

export def "test list-workflow-runs with workflow filter" [] {
  let mock_output = sample-workflow-runs
  let result = with-env {MOCK_gh_run_list___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_event_createdAt___workflow_CI: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflow-runs
      list-workflow-runs --workflow CI
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"
}

export def "test list-workflow-runs with branch filter" [] {
  let mock_output = sample-workflow-runs
  let result = with-env {MOCK_gh_run_list___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_event_createdAt___branch_main: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflow-runs
      list-workflow-runs --branch main
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"
}

export def "test list-workflow-runs with status filter" [] {
  let mock_output = sample-workflow-runs
  let result = with-env {MOCK_gh_run_list___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_event_createdAt___status_completed: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu list-workflow-runs
      list-workflow-runs --status completed
    "
  }
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"
}

# =============================================================================
# get-workflow-run tests
# =============================================================================

export def "test get-workflow-run returns run details" [] {
  let mock_output = sample-workflow-run
  let result = with-env {MOCK_gh_run_view_11111___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_headSha_event_createdAt_updatedAt_url_jobs: (mock-success $mock_output)} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu get-workflow-run
      get-workflow-run 11111
    "
  }
  let parsed = $result | from json

  assert (($parsed | get databaseId) == 11111) "Should return correct run ID"
  assert (($parsed | get status) == "completed") "Should return correct status"
  assert (($parsed | get jobs | length) == 2) "Should have 2 jobs"
}

export def "test get-workflow-run handles not found" [] {
  let result = with-env {MOCK_gh_run_view_99999___json_databaseId_displayTitle_status_conclusion_workflowName_headBranch_headSha_event_createdAt_updatedAt_url_jobs: (mock-error "run 99999 not found")} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu get-workflow-run
      get-workflow-run 99999
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "not found") "Should contain error message"
}

# =============================================================================
# run-workflow tests (write - blocked in readonly mode)
# =============================================================================

export def "test run-workflow blocked in readonly mode" [] {
  let result = with-env {MCP_GITHUB_MODE: "readonly"} {
    do {
      nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu run-workflow
      run-workflow ci.yaml
    "
    } | complete
  }

  assert ($result.exit_code != 0) "Should fail"
  assert ($result.stderr | str contains "readwrite mode") "Should mention readwrite mode"
}

export def "test run-workflow allowed in readwrite mode" [] {
  # Mock key: workflow_run_ci_yaml (dots replaced)
  # Default mode is readwrite, so no need to set MCP_GITHUB_MODE
  let result = with-env {MOCK_gh_workflow_run_ci_yaml: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu run-workflow
      run-workflow ci.yaml | to json
    "
  }
  let parsed = $result | from json

  assert $parsed.success "Should succeed"
  assert ($parsed.message | str contains "ci.yaml") "Should mention workflow"
}

export def "test run-workflow with ref" [] {
  # Mock key: workflow_run_ci_yaml___ref_feature_branch (dots and dashes replaced)
  let result = with-env {MOCK_gh_workflow_run_ci_yaml___ref_feature_branch: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu run-workflow
      run-workflow ci.yaml --ref feature-branch | to json
    "
  }
  let parsed = $result | from json

  assert $parsed.success "Should succeed"
}

export def "test run-workflow with inputs" [] {
  # Mock key: workflow_run_deploy_yaml__f_environment_staging
  # -f becomes _f (dash to underscore), = becomes _ 
  let result = with-env {MOCK_gh_workflow_run_deploy_yaml__f_environment_staging: (mock-success "")} {
    nu --no-config-file -c "
      use tools/gh/tests/mocks.nu *
      use tools/gh/workflows.nu run-workflow
      run-workflow deploy.yaml --inputs {environment: staging} | to json
    "
  }
  let parsed = $result | from json

  assert $parsed.success "Should succeed"
}
