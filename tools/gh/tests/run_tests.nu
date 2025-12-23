#!/usr/bin/env nu

# Test runner for GitHub tool
# Must be run from project root directory

def main [] {
  print "Running GitHub tool tests...\n"

  # Verify we're in the project root
  if not ("tools/gh/mod.nu" | path exists) {
    print "Error: Must run from project root directory"
    exit 1
  }

  # Get NU_LIB_DIRS from environment for nu-mock support
  # Note: NU_LIB_DIRS from shell env is a string, convert to what nu expects
  let nu_lib_dirs = if "NU_LIB_DIRS" in $env {
    $env.NU_LIB_DIRS # Will be a string from shell env
  } else {
    null
  }

  # Discover all test files
  let test_files = glob tools/gh/tests/test_*.nu

  if ($test_files | is-empty) {
    print "No test files found (looking for tools/gh/tests/test_*.nu)"
    exit 0
  }

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

      # Run discovery - capture both stdout and stderr
      let discovery_result = if $nu_lib_dirs != null {
        do { nu --no-config-file --include-path $nu_lib_dirs -c $discover_script } | complete
      } else {
        do { nu --no-config-file -c $discover_script } | complete
      }

      if $discovery_result.exit_code != 0 {
        print $"ERROR: Failed to parse test file!"
        print $discovery_result.stderr
        # Return a failure record for the parse error
        [{file: $test_file test: "PARSE_ERROR" status: "fail" error: $"Parse error in ($test_file)"}]
      } else {
        let test_commands = ($discovery_result.stdout | from json)

        print $"Found ($test_commands | length) tests\n"

        # Run each test
        $test_commands | each {|test_name|
          let test_result = if $nu_lib_dirs != null {
            do { nu --no-config-file --include-path $nu_lib_dirs -c $"source ($test_file); ($test_name)" } | complete
          } else {
            do { nu --no-config-file -c $"source ($test_file); ($test_name)" } | complete
          }

          if $test_result.exit_code == 0 {
            print $"✓ ($test_name)"
            {file: $test_file test: $test_name status: "pass"}
          } else {
            let error_msg = if ($test_result.stderr | str trim | is-not-empty) {
              $test_result.stderr | str trim
            } else {
              "Test failed"
            }
            print $"✗ ($test_name): ($error_msg)"
            {file: $test_file test: $test_name status: "fail" error: $error_msg}
          }
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
