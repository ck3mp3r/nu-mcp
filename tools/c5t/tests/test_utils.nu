# Tests for utils.nu - validation functions
# Focus: One valid case + one invalid case per validator

use std/assert

# --- List Validation ---

export def "test validate-list-input accepts valid" [] {
  use ../utils.nu validate-list-input

  let result = validate-list-input {name: "Test List" description: "A test"}
  assert $result.valid
}

export def "test validate-list-input rejects empty name" [] {
  use ../utils.nu validate-list-input

  let result = validate-list-input {name: "  "}
  assert (not $result.valid)
  assert ($result.error | str contains "empty")
}

# --- Item Validation ---

export def "test validate-item-input accepts valid" [] {
  use ../utils.nu validate-item-input

  let result = validate-item-input {list_id: "123" content: "Test item"}
  assert $result.valid
}

export def "test validate-item-input rejects missing content" [] {
  use ../utils.nu validate-item-input

  let result = validate-item-input {list_id: "123"}
  assert (not $result.valid)
  assert ($result.error | str contains "content")
}

export def "test validate-task-update-input accepts valid" [] {
  use ../utils.nu validate-task-update-input

  let result = validate-task-update-input {list_id: "123" task_id: "456"}
  assert $result.valid
}

export def "test validate-task-update-input rejects missing task_id" [] {
  use ../utils.nu validate-task-update-input

  let result = validate-task-update-input {list_id: "123"}
  assert (not $result.valid)
  assert ($result.error | str contains "task_id")
}

# --- Note Validation ---

export def "test validate-note-input accepts valid" [] {
  use ../utils.nu validate-note-input

  let result = validate-note-input {title: "Test" content: "Content"}
  assert $result.valid
}

export def "test validate-note-input rejects empty title" [] {
  use ../utils.nu validate-note-input

  let result = validate-note-input {title: "  " content: "Content"}
  assert (not $result.valid)
  assert ($result.error | str contains "empty")
}

# --- Status/Priority Validation ---

export def "test validate-status accepts all valid" [] {
  use ../utils.nu validate-status

  for status in ["backlog" "todo" "in_progress" "review" "done" "cancelled"] {
    let result = validate-status $status
    assert $result.valid
  }
}

export def "test validate-status rejects invalid" [] {
  use ../utils.nu validate-status

  let result = validate-status "invalid"
  assert (not $result.valid)
}

export def "test validate-priority accepts 1-5" [] {
  use ../utils.nu validate-priority

  for p in 1..5 {
    let result = validate-priority $p
    assert $result.valid
  }
}

export def "test validate-priority rejects out of range" [] {
  use ../utils.nu validate-priority

  assert (not (validate-priority 0).valid)
  assert (not (validate-priority 6).valid)
  assert (not (validate-priority -1).valid)
}
