# Tests for mod.nu - MCP interface and tool routing

use std/assert

# Test main list-tools returns valid JSON array
export def "test main list-tools returns json array" [] {
  let test_script = "
source tools/c5t/mod.nu
main list-tools
"

  let output = nu -c $test_script

  # Should be valid JSON
  let parsed = $output | from json

  # Should be a list
  assert ($parsed | describe | str starts-with "list")
}

# Test main call-tool with unknown tool
export def "test main call-tool rejects unknown tool" [] {
  let test_script = "
source tools/c5t/mod.nu
main call-tool 'unknown_tool' '{}'
"

  let output = nu -c $test_script | complete

  # Should fail with error
  assert ($output.exit_code != 0)
  assert ($output.stderr | str contains "Unknown tool")
}

# Test main call-tool parses string args
export def "test main call-tool parses string args" [] {
  let test_script = "
source tools/c5t/mod.nu
main call-tool 'test_tool' '{\"param\": \"value\"}'
"

  let output = nu -c $test_script | complete

  # Should fail with "Unknown tool", not parse error
  assert ($output.exit_code != 0)
  assert ($output.stderr | str contains "Unknown tool")
}

# Test main call-tool parses record args  
export def "test main call-tool parses record args" [] {
  let test_script = "
source tools/c5t/mod.nu
main call-tool 'test_tool' {param: \"value\"}
"

  let output = nu -c $test_script | complete

  # Should fail with "Unknown tool", not parse error
  assert ($output.exit_code != 0)
  assert ($output.stderr | str contains "Unknown tool")
}
