# Tests for utils.nu - ID generation and validation functions

use std/assert
use mocks.nu *

# Test generate-id returns properly formatted ID
export def "test generate-id returns formatted id" [] {
  with-env {
    MOCK_date_now: ({output: "2025-12-14T13:45:30" exit_code: 0} | to json)
    MOCK_random_int_1000..9999: ({output: "5678" exit_code: 0} | to json)
  } {
    # Import and call generate-id
    use ../utils.nu generate-id
    let id = generate-id

    assert equal $id "20251214134530-5678"
  }
}

# Test generate-id produces unique IDs with different timestamps
export def "test generate-id produces unique ids" [] {
  with-env {
    MOCK_date_now: ({output: "2025-12-14T13:45:30" exit_code: 0} | to json)
    MOCK_random_int_1000..9999: ({output: "1111" exit_code: 0} | to json)
  } {
    use ../utils.nu generate-id
    let id1 = generate-id

    # Change timestamp for second call
    with-env {
      MOCK_date_now: ({output: "2025-12-14T13:45:31" exit_code: 0} | to json)
      MOCK_random_int_1000..9999: ({output: "2222" exit_code: 0} | to json)
    } {
      let id2 = generate-id

      assert ($id1 != $id2)
    }
  }
}

# Test validate-list-input accepts valid input
export def "test validate-list-input with valid input" [] {
  use ../utils.nu validate-list-input

  let args = {name: "Test List" description: "A test" tags: ["test"]}
  let result = validate-list-input $args

  assert $result.valid
}

# Test validate-list-input rejects missing name
export def "test validate-list-input rejects missing name" [] {
  use ../utils.nu validate-list-input

  let args = {description: "No name"}
  let result = validate-list-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "name")
}

# Test validate-list-input rejects empty name
export def "test validate-list-input rejects empty name" [] {
  use ../utils.nu validate-list-input

  let args = {name: "  " description: "Empty name"}
  let result = validate-list-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "empty")
}

# Test validate-item-input accepts valid input
export def "test validate-item-input with valid input" [] {
  use ../utils.nu validate-item-input

  let args = {list_id: "123" content: "Test item"}
  let result = validate-item-input $args

  assert $result.valid
}

# Test validate-item-input rejects missing list_id
export def "test validate-item-input rejects missing list_id" [] {
  use ../utils.nu validate-item-input

  let args = {content: "No list_id"}
  let result = validate-item-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "list_id")
}

# Test validate-item-input rejects missing content
export def "test validate-item-input rejects missing content" [] {
  use ../utils.nu validate-item-input

  let args = {list_id: "123"}
  let result = validate-item-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "content")
}

# Test validate-item-input rejects empty content
export def "test validate-item-input rejects empty content" [] {
  use ../utils.nu validate-item-input

  let args = {list_id: "123" content: "   "}
  let result = validate-item-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "empty")
}

# Test validate-note-input accepts valid input
export def "test validate-note-input with valid input" [] {
  use ../utils.nu validate-note-input

  let args = {title: "Test Note" content: "Note content"}
  let result = validate-note-input $args

  assert $result.valid
}

# Test validate-note-input rejects missing title
export def "test validate-note-input rejects missing title" [] {
  use ../utils.nu validate-note-input

  let args = {content: "No title"}
  let result = validate-note-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "title")
}

# Test validate-note-input rejects missing content
export def "test validate-note-input rejects missing content" [] {
  use ../utils.nu validate-note-input

  let args = {title: "No content"}
  let result = validate-note-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "content")
}

# Test validate-note-input rejects empty title
export def "test validate-note-input rejects empty title" [] {
  use ../utils.nu validate-note-input

  let args = {title: "  " content: "Empty title"}
  let result = validate-note-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "empty")
}

# Test validate-note-input rejects empty content
export def "test validate-note-input rejects empty content" [] {
  use ../utils.nu validate-note-input

  let args = {title: "Title" content: "   "}
  let result = validate-note-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "empty")
}

# Test validate-status accepts valid statuses
export def "test validate-status accepts all valid statuses" [] {
  use ../utils.nu validate-status

  let valid_statuses = ["backlog" "todo" "in_progress" "review" "done" "cancelled"]

  for status in $valid_statuses {
    let result = validate-status $status
    assert $result.valid
  }
}

# Test validate-status rejects invalid status
export def "test validate-status rejects invalid status" [] {
  use ../utils.nu validate-status

  let result = validate-status "invalid_status"

  assert (not $result.valid)
  assert ($result.error | str contains "Invalid status")
}

# Test validate-priority accepts 1-5
export def "test validate-priority accepts 1 through 5" [] {
  use ../utils.nu validate-priority

  for priority in 1..5 {
    let result = validate-priority $priority
    assert $result.valid
  }
}

# Test validate-priority rejects 0
export def "test validate-priority rejects 0" [] {
  use ../utils.nu validate-priority

  let result = validate-priority 0

  assert (not $result.valid)
  assert ($result.error | str contains "Invalid priority")
}

# Test validate-priority rejects 6
export def "test validate-priority rejects 6" [] {
  use ../utils.nu validate-priority

  let result = validate-priority 6

  assert (not $result.valid)
  assert ($result.error | str contains "Invalid priority")
}

# Test validate-priority rejects negative
export def "test validate-priority rejects negative" [] {
  use ../utils.nu validate-priority

  let result = validate-priority -1

  assert (not $result.valid)
  assert ($result.error | str contains "Invalid priority")
}

# Test validate-item-update-input accepts valid input
export def "test validate-item-update-input accepts valid input" [] {
  use ../utils.nu validate-item-update-input

  let args = {list_id: "123" item_id: "456"}
  let result = validate-item-update-input $args

  assert $result.valid
}

# Test validate-item-update-input rejects missing list_id
export def "test validate-item-update-input rejects missing list_id" [] {
  use ../utils.nu validate-item-update-input

  let args = {item_id: "456"}
  let result = validate-item-update-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "list_id")
}

# Test validate-item-update-input rejects missing item_id
export def "test validate-item-update-input rejects missing item_id" [] {
  use ../utils.nu validate-item-update-input

  let args = {list_id: "123"}
  let result = validate-item-update-input $args

  assert (not $result.valid)
  assert ($result.error | str contains "item_id")
}
