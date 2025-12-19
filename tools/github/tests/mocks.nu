# Mock wrapper functions for gh CLI used in github tool tests
# These check for MOCK_* environment variables for testing

# Mock gh command - intercepts gh CLI calls
# Environment variable format: MOCK_gh_<subcommand>_<args>
# Example: MOCK_gh_workflow_list = '{"exit_code": 0, "output": "[...]"}'
export def --wrapped gh [...rest] {
  # Build mock variable name from args
  # Replace all special characters with underscores for valid env var names
  let args = ($rest | str join "_" | str replace --all " " "_" | str replace --all "-" "_" | str replace --all "," "_" | str replace --all "." "_" | str replace --all "=" "_")
  let mock_var = $"MOCK_gh_($args)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    if $mock_data.exit_code != 0 {
      error make {msg: ($mock_data.error? | default "gh command failed")}
    }
    $mock_data.output
  } else {
    # No mock found - error! Never call real CLI in tests
    error make {msg: $"No mock found for gh command. Expected env var: ($mock_var)"}
  }
}

# Helper to create mock data for successful responses
export def mock-success [output: string] {
  {exit_code: 0 output: $output} | to json
}

# Helper to create mock data for error responses
export def mock-error [error: string exit_code: int = 1] {
  {exit_code: $exit_code error: $error output: ""} | to json
}

# Helper to build mock variable name from gh args
export def mock-var-name [...args: string] {
  let joined = ($args | str join "_" | str replace --all " " "_" | str replace --all "-" "_")
  $"MOCK_gh_($joined)"
}

# Mock git command - intercepts git CLI calls
export def --wrapped git [...rest] {
  let args = ($rest | str join "_" | str replace --all " " "_" | str replace --all "-" "_" | str replace --all "," "_" | str replace --all "." "_" | str replace --all "=" "_")
  let mock_var = $"MOCK_git_($args)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    if $mock_data.exit_code != 0 {
      error make {msg: ($mock_data.error? | default "git command failed")}
    }
    $mock_data.output
  } else {
    # No mock found - error! Never call real CLI in tests
    error make {msg: $"No mock found for git command. Expected env var: ($mock_var)"}
  }
}
