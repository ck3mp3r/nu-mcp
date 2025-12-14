#!/usr/bin/env nu

# Test runner for c5t tool
# Must be run from project root directory

def main [] {
  print "Running c5t tests...\n"

  # Verify we're in the project root
  if not ("tools/c5t/mod.nu" | path exists) {
    print "Error: Must run from project root directory"
    exit 1
  }

  # Discover all test files
  let test_files = glob tools/c5t/tests/test_*.nu

  let results = (
    $test_files | each {|test_file|
      print $"=== Running tests from ($test_file) ==="

      # Create a temporary script to discover tests
      let discover_script = $"
use std
source ($test_file)

scope commands 
  | where type == 'custom' 
  | where name starts-with 'test ' 
  | get name 
  | to json"

      # Run discovery
      let test_commands = (
        nu --no-config-file -c $discover_script | from json
      )

      print $"Found ($test_commands | length) tests\n"

      # Run each test
      $test_commands | each {|test_name|
        try {
          nu --no-config-file -c $"source ($test_file); ($test_name)"
          print $"✓ ($test_name)"
          {file: $test_file test: $test_name status: "pass"}
        } catch {|err|
          print $"✗ ($test_name): ($err.msg)"
          {file: $test_file test: $test_name status: "fail" error: $err.msg}
        }
      }
    } | flatten
  )

  # Summary
  let passed = $results | where status == "pass" | length
  let failed = $results | where status == "fail" | length
  let total = $results | length

  print ""
  print $"Results: ($passed)/($total) passed, ($failed) failed"

  if $failed > 0 {
    print "\nFailed tests:"
    $results | where status == "fail" | each {|test|
      print $"  - ($test.test): ($test.error)"
    }
    exit 1
  }
}
