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

  mut total_passed = 0
  mut total_failed = 0
  mut failed_suites = []

  # Run each test suite
  for runner in $test_runners {
    let tool_name = $runner | path dirname | path dirname | path basename

    print $"=== Running ($tool_name) tests ==="

    let result = (^nu $runner | complete)

    # Extract pass/fail counts from output
    let results_lines = $result.stdout | lines | where {|line| $line | str contains "Results:" }

    if ($results_lines | length) > 0 {
      let results_line = $results_lines | first

      let parts = $results_line | parse "Results: {passed}/{total} passed, {failed} failed"
      if ($parts | length) > 0 {
        let counts = $parts | first
        $total_passed = $total_passed + ($counts.passed | into int)
        $total_failed = $total_failed + ($counts.failed | into int)

        if ($counts.failed | into int) > 0 {
          $failed_suites = ($failed_suites | append $tool_name)
        }
      }
    }

    print $result.stdout

    if $result.exit_code != 0 {
      print $result.stderr
      $failed_suites = ($failed_suites | append $tool_name)
    }

    print ""
  }

  # Summary
  print "===================================="
  print "Test Summary"
  print "===================================="
  print $"Total passed: ($total_passed)"
  print $"Total failed: ($total_failed)"

  if ($failed_suites | length) > 0 {
    print ""
    print $"Failed suites: ($failed_suites | str join ', ')"
    exit 1
  } else {
    print ""
    print "✅ All tests passed!"
    exit 0
  }
}
