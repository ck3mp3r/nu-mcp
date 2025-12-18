# Tests for subtask functionality
# Focus: Creating, listing, and managing subtasks

use std/assert

# Test upsert_task schema supports parent_id parameter
export def "test upsert_task schema has parent_id" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "upsert_task" | first

  assert ("parent_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.parent_id.type == "integer")
}

# Test list_tasks shows subtasks with parent tasks
export def "test list_tasks includes subtasks" [] {
  # This test will verify the formatter handles subtasks
  # Implementation will come after we add the tool
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json

  # Verify list_tasks tool exists
  let tool = $tools | where name == "list_tasks" | first
  assert ($tool.name == "list_tasks")
}

# Test get_subtasks tool exists in schema
export def "test get_subtasks tool exists" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let names = $tools | get name

  assert ("get_subtasks" in $names)
}

# Test get_subtasks schema has required parameters
export def "test get_subtasks schema has required params" [] {
  let output = nu tools/c5t/mod.nu list-tools
  let tools = $output | from json
  let tool = $tools | where name == "get_subtasks" | first

  assert ("list_id" in ($tool.input_schema.properties | columns))
  assert ("parent_id" in ($tool.input_schema.properties | columns))
  assert ($tool.input_schema.properties.list_id.type == "integer")
  assert ($tool.input_schema.properties.parent_id.type == "integer")
}
