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

# Test list-tools includes c5t_create_list
export def "test list-tools includes c5t_create_list" [] {
  let test_script = "
source tools/c5t/mod.nu
main list-tools
"

  let output = nu -c $test_script
  let tools = $output | from json

  # Should have c5t_create_list tool
  let create_list_tool = $tools | where name == "c5t_create_list" | first
  assert ($create_list_tool.name == "c5t_create_list")
  assert ($create_list_tool.description != null)
  assert ($create_list_tool.input_schema != null)
}

# Test list-tools includes c5t_list_active
export def "test list-tools includes c5t_list_active" [] {
  let test_script = "
source tools/c5t/mod.nu
main list-tools
"

  let output = nu -c $test_script
  let tools = $output | from json

  # Should have c5t_list_active tool
  let list_active_tool = $tools | where name == "c5t_list_active" | first
  assert ($list_active_tool.name == "c5t_list_active")
  assert ($list_active_tool.description != null)
  assert ($list_active_tool.input_schema != null)
}

# Test c5t_create_list validates missing name
export def "test c5t_create_list validates missing name" [] {
  let test_script = "
source tools/c5t/mod.nu
main call-tool 'c5t_create_list' '{}'
"

  let output = nu -c $test_script

  # Should return error message about missing name
  assert ($output | str contains "Missing required field")
  assert ($output | str contains "name")
}

# Test c5t_create_list validates empty name
export def "test c5t_create_list validates empty name" [] {
  let test_script = "
source tools/c5t/mod.nu
main call-tool 'c5t_create_list' '{\"name\": \"\"}'
"

  let output = nu -c $test_script

  # Should return error message about empty name
  assert ($output | str contains "cannot be empty")
}
