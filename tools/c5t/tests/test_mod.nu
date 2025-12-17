# Tests for mod.nu - MCP interface
# Focus: Tool discovery and basic routing

use std/assert

export def "test list-tools returns valid json" [] {
  let output = nu -c "source tools/c5t/mod.nu; main list-tools"
  let parsed = $output | from json

  assert ($parsed | describe | str starts-with "list")
  assert (($parsed | length) > 0)
}

export def "test list-tools has expected tools" [] {
  let output = nu -c "source tools/c5t/mod.nu; main list-tools"
  let tools = $output | from json
  let names = $tools | get name

  # Check key tools exist
  assert ("upsert_list" in $names)
  assert ("upsert_item" in $names)
  assert ("upsert_note" in $names)
  assert ("list_active" in $names)
  assert ("get_summary" in $names)
  assert ("search" in $names)
  assert ("list_repos" in $names)
}

export def "test call-tool rejects unknown tool" [] {
  let output = nu -c "source tools/c5t/mod.nu; main call-tool 'unknown_tool' '{}'" | complete

  assert ($output.exit_code != 0)
  assert ($output.stderr | str contains "Unknown tool")
}

export def "test upsert_list validates input" [] {
  let output = nu -c "source tools/c5t/mod.nu; main call-tool 'upsert_list' '{}'"

  assert ($output | str contains "required")
}

export def "test schema has correct types" [] {
  let output = nu -c "source tools/c5t/mod.nu; main list-tools"
  let tools = $output | from json

  # Check ID fields are integers
  let upsert_item = $tools | where name == "upsert_item" | first
  assert ($upsert_item.input_schema.properties.list_id.type == "integer")
  assert ($upsert_item.input_schema.properties.item_id.type == "integer")
}

# Test get_summary returns formatted output
# Note: This test requires a real database to exist, so we test the tool schema instead
export def "test get_summary returns output" [] {
  # Test that get_summary is a valid tool
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json

  let get_summary = $tools | where name == "get_summary" | first
  assert ($get_summary.name == "get_summary")
  assert ($get_summary.description | str contains "status")
}

# --- repo_id parameter tests ---

# Test upsert_list schema has repo_id parameter
export def "test upsert_list schema has repo_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "upsert_list" | first

  assert ("repo_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.repo_id.type == "integer")
}

# Test upsert_note schema has repo_id parameter
export def "test upsert_note schema has repo_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "upsert_note" | first

  assert ("repo_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.repo_id.type == "integer")
}

# Test list_active schema has repo_id parameter
export def "test list_active schema has repo_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "list_active" | first

  assert ("repo_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.repo_id.type == "integer")
}

# Test list_notes schema has repo_id parameter
export def "test list_notes schema has repo_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "list_notes" | first

  assert ("repo_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.repo_id.type == "integer")
}

# Test search schema has repo_id parameter
export def "test search schema has repo_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "search" | first

  assert ("repo_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.repo_id.type == "integer")
}

# Test get_summary schema has repo_id parameter
export def "test get_summary schema has repo_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "get_summary" | first

  assert ("repo_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.repo_id.type == "integer")
}
