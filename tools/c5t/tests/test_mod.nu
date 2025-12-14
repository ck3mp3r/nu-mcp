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

# Test schema types match function signatures for ID parameters
export def "test schema types match function signatures" [] {
  let test_script = "
source tools/c5t/mod.nu
main list-tools
"

  let output = nu -c $test_script
  let tools = $output | from json

  # Check c5t_add_item has integer list_id
  let add_item = $tools | where name == "c5t_add_item" | first
  assert ($add_item.input_schema.properties.list_id.type == "integer")

  # Check c5t_update_item_status has integer list_id and item_id
  let update_status = $tools | where name == "c5t_update_item_status" | first
  assert ($update_status.input_schema.properties.list_id.type == "integer")
  assert ($update_status.input_schema.properties.item_id.type == "integer")

  # Check c5t_update_item_priority has integer list_id and item_id
  let update_priority = $tools | where name == "c5t_update_item_priority" | first
  assert ($update_priority.input_schema.properties.list_id.type == "integer")
  assert ($update_priority.input_schema.properties.item_id.type == "integer")

  # Check c5t_complete_item has integer list_id and item_id
  let complete_item = $tools | where name == "c5t_complete_item" | first
  assert ($complete_item.input_schema.properties.list_id.type == "integer")
  assert ($complete_item.input_schema.properties.item_id.type == "integer")

  # Check c5t_list_items has integer list_id
  let list_items = $tools | where name == "c5t_list_items" | first
  assert ($list_items.input_schema.properties.list_id.type == "integer")

  # Check c5t_list_active_items has integer list_id
  let list_active_items = $tools | where name == "c5t_list_active_items" | first
  assert ($list_active_items.input_schema.properties.list_id.type == "integer")

  # Check c5t_update_notes has integer list_id
  let update_notes = $tools | where name == "c5t_update_notes" | first
  assert ($update_notes.input_schema.properties.list_id.type == "integer")

  # Check c5t_get_note has integer note_id
  let get_note = $tools | where name == "c5t_get_note" | first
  assert ($get_note.input_schema.properties.note_id.type == "integer")
}

# Test c5t_list_items handles empty list (no items)
export def "test c5t_list_items handles empty list" [] {
  let test_script = '
source tools/c5t/tests/mocks.nu

# First query: get the list (FROM todo_list)
$env.MOCK_query_db_TODO_LIST = ({
  output: [{
    id: 1
    name: "Test List"
    description: null
    notes: null
    tags: null
    created_at: "2025-01-01 12:00:00"
    updated_at: "2025-01-01 12:00:00"
  }]
  exit_code: 0
})

# Second query: get items (FROM todo_item) - returns empty
$env.MOCK_query_db_EMPTY_ITEMS = true

source tools/c5t/mod.nu
main call-tool "c5t_list_items" "{\"list_id\": 1}"
'

  let output = nu -c $test_script

  # Should not crash, should return a message about no items
  assert ($output | str contains "No items in this list")
}
