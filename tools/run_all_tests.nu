#!/usr/bin/env nu
# Automatically discover and run all tool test suites

def main [] {
  print "Discovering and running all tool tests..."
  print ""

  # Find all run_tests.nu files in tools/*/tests/ directories
  let test_runners = (
    glob "tools/*/tests/run_tests.nu"
    | sort
  )

  if ($test_runners | is-empty) {
    print "No test suites found"
    exit 1
  }

  let count = $test_runners | length
  print $"Found ($count) test suites:"
  for runner in $test_runners {
    let tool_name = $runner | path dirname | path dirname | path basename
    print $"  - ($tool_name)"
  }
  print ""

  mut failed_suites = []

  # Run each test suite
  for runner in $test_runners {
    let tool_name = $runner | path dirname | path dirname | path basename

    print $"=== Running ($tool_name) tests ==="

    # Run the test suite and let output stream naturally
    # Convert NU_LIB_DIRS list back to colon-separated string for child process
    if "NU_LIB_DIRS" in $env {
      let lib_dirs_str = $env.NU_LIB_DIRS | path expand | str join ':'
      with-env {NU_LIB_DIRS: $lib_dirs_str} {
        ^nu $runner
      }
    } else {
      ^nu $runner
    }

    # Capture exit code
    let exit_code = $env.LAST_EXIT_CODE

    if $exit_code != 0 {
      $failed_suites = ($failed_suites | append $tool_name)
    }

    print ""
  }

  # Summary
  print "===================================="
  print "Test Summary"
  print "===================================="

  if ($failed_suites | length) > 0 {
    print $"Failed suites: ($failed_suites | str join ', ')"
    exit 1
  } else {
    print "✅ All tests passed!"
    exit 0
  }
}
