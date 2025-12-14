# Tests for mod.nu - MCP interface and tool routing

use std/assert

# Test main list-tools returns valid JSON array
export def "test main list-tools returns json array" [] {
  # Source the file directly to get access to main subcommands
  let output = nu --no-config-file ../mod.nu list-tools

  # Should be valid JSON
  let parsed = $output | from json

  # Should be a list
  assert ($parsed | describe | str starts-with "list")
}

# Test main call-tool with unknown tool
export def "test main call-tool rejects unknown tool" [] {
  let result = nu --no-config-file ../mod.nu call-tool "unknown_tool" "{}" | complete

  # Should fail with error
  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "Unknown tool")
}

# Test main call-tool parses string args
export def "test main call-tool parses string args" [] {
  # This will fail because the tool doesn't exist yet, but we're testing arg parsing
  let result = nu --no-config-file ../mod.nu call-tool "test_tool" '{"param": "value"}' | complete

  # Should fail with "Unknown tool", not parse error
  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "Unknown tool")
  assert (not ($result.stderr | str contains "parse"))
}

# Test main call-tool parses record args  
export def "test main call-tool parses record args" [] {
  # Record args need to be passed as JSON string when calling via nu command
  let result = nu --no-config-file ../mod.nu call-tool "test_tool" '{"param":"value"}' | complete

  # Should fail with "Unknown tool", not parse error
  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "Unknown tool")
  assert (not ($result.stderr | str contains "parse"))
}
