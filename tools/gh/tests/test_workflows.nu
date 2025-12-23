# Tests for GitHub workflow tools
# Mocks must be imported BEFORE the module under test

use std/assert
use nu-mock *
use test_helpers.nu [ sample-workflow-list sample-workflow-runs sample-workflow-run ]
use wrappers.nu *

# =============================================================================
# list-workflows tests
# =============================================================================

export def --env "test list-workflows returns workflow list" [] {
  mock reset

  let mock_output = sample-workflow-list
  mock register gh {
    args: ['workflow' 'list' '--json' 'id,name,path,state']
    returns: $mock_output
  }

  use ../workflows.nu list-workflows
  let result = list-workflows
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return 2 workflows"
  assert (($parsed | get 0 | get name) == "CI") "First workflow should be CI"

  mock verify
}

export def --env "test list-workflows with empty result" [] {
  mock reset

  mock register gh {
    args: ['workflow' 'list' '--json' 'id,name,path,state']
    returns: "[]"
  }

  use ../workflows.nu list-workflows
  let result = list-workflows
  let parsed = $result | from json

  assert (($parsed | length) == 0) "Should return empty list"

  mock verify
}

export def --env "test list-workflows handles gh error" [] {
  mock reset

  mock register gh {
    args: ['workflow' 'list' '--json' 'id,name,path,state']
    returns: "not a git repository"
    exit_code: 1
  }

  use ../workflows.nu list-workflows
  let result = try {
    list-workflows
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "not a git repository") "Should contain error message"

  mock verify
}

# =============================================================================
# list-workflow-runs tests
# =============================================================================

export def --env "test list-workflow-runs returns runs" [] {
  mock reset

  let mock_output = sample-workflow-runs
  mock register gh {
    args: ['run' 'list' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt']
    returns: $mock_output
  }

  use ../workflows.nu list-workflow-runs
  let result = list-workflow-runs
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return 2 runs"
  assert (($parsed | get 0 | get status) == "completed") "First run should be completed"

  mock verify
}

export def --env "test list-workflow-runs with limit" [] {
  mock reset

  let mock_output = sample-workflow-runs
  mock register gh {
    args: ['run' 'list' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt' '--limit' '5']
    returns: $mock_output
  }

  use ../workflows.nu list-workflow-runs
  let result = list-workflow-runs --limit 5
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"

  mock verify
}

export def --env "test list-workflow-runs with workflow filter" [] {
  mock reset

  let mock_output = sample-workflow-runs
  mock register gh {
    args: ['run' 'list' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt' '--workflow' 'CI']
    returns: $mock_output
  }

  use ../workflows.nu list-workflow-runs
  let result = list-workflow-runs --workflow CI
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"

  mock verify
}

export def --env "test list-workflow-runs with branch filter" [] {
  mock reset

  let mock_output = sample-workflow-runs
  mock register gh {
    args: ['run' 'list' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt' '--branch' 'main']
    returns: $mock_output
  }

  use ../workflows.nu list-workflow-runs
  let result = list-workflow-runs --branch main
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"

  mock verify
}

export def --env "test list-workflow-runs with status filter" [] {
  mock reset

  let mock_output = sample-workflow-runs
  mock register gh {
    args: ['run' 'list' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,event,createdAt' '--status' 'completed']
    returns: $mock_output
  }

  use ../workflows.nu list-workflow-runs
  let result = list-workflow-runs --status completed
  let parsed = $result | from json

  assert (($parsed | length) == 2) "Should return runs"

  mock verify
}

# =============================================================================
# get-workflow-run tests
# =============================================================================

export def --env "test get-workflow-run returns run details" [] {
  mock reset

  let mock_output = sample-workflow-run
  mock register gh {
    args: ['run' 'view' '11111' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,headSha,event,createdAt,updatedAt,url,jobs']
    returns: $mock_output
  }

  use ../workflows.nu get-workflow-run
  let result = get-workflow-run 11111
  let parsed = $result | from json

  assert (($parsed | get databaseId) == 11111) "Should return correct run ID"
  assert (($parsed | get status) == "completed") "Should return correct status"
  assert (($parsed | get jobs | length) == 2) "Should have 2 jobs"

  mock verify
}

export def --env "test get-workflow-run handles not found" [] {
  mock reset

  mock register gh {
    args: ['run' 'view' '99999' '--json' 'databaseId,displayTitle,status,conclusion,workflowName,headBranch,headSha,event,createdAt,updatedAt,url,jobs']
    returns: "run 99999 not found"
    exit_code: 1
  }

  use ../workflows.nu get-workflow-run
  let result = try {
    get-workflow-run 99999
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "not found") "Should contain error message"

  mock verify
}

# =============================================================================
# run-workflow tests (write - blocked in readonly mode)
# =============================================================================

export def --env "test run-workflow blocked in readonly mode" [] {
  mock reset
  $env.MCP_GITHUB_MODE = "readonly"

  use ../workflows.nu run-workflow
  let result = try {
    run-workflow ci.yaml
    {success: true}
  } catch {|err|
    {success: false error: $err.msg}
  }

  assert (not $result.success) "Should fail"
  assert ($result.error | str contains "readwrite mode") "Should mention readwrite mode"

  mock verify
}

export def --env "test run-workflow allowed in readwrite mode" [] {
  mock reset

  mock register gh {
    args: ['workflow' 'run' 'ci.yaml']
    returns: ""
  }

  use ../workflows.nu run-workflow
  let result = run-workflow ci.yaml

  assert $result.success "Should succeed"
  assert ($result.message | str contains "ci.yaml") "Should mention workflow"

  mock verify
}

export def --env "test run-workflow with ref" [] {
  mock reset

  mock register gh {
    args: ['workflow' 'run' 'ci.yaml' '--ref' 'feature-branch']
    returns: ""
  }

  use ../workflows.nu run-workflow
  let result = run-workflow ci.yaml --ref feature-branch

  assert $result.success "Should succeed"

  mock verify
}

export def --env "test run-workflow with inputs" [] {
  mock reset

  mock register gh {
    args: ['workflow' 'run' 'deploy.yaml' '-f' 'environment=staging']
    returns: ""
  }

  use ../workflows.nu run-workflow
  let result = run-workflow deploy.yaml --inputs {environment: staging}

  assert $result.success "Should succeed"

  mock verify
}
