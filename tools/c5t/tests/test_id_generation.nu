# Tests for ID generation utilities
# TDD tests for generate-id function that creates 8-char short SHA IDs

use std/assert
use ./test_helpers.nu *

# --- ID Format Tests ---

export def "test generate-id returns 8 character string" [] {
  use ../utils.nu generate-id

  let id = generate-id
  assert equal ($id | str length) 8
}

export def "test generate-id returns lowercase hex characters only" [] {
  use ../utils.nu generate-id

  let id = generate-id
  # Should match pattern of 8 lowercase hex chars
  let is_valid_hex = ($id | str replace --regex '^[0-9a-f]{8}$' 'valid') == 'valid'
  assert $is_valid_hex $"Expected hex string, got: ($id)"
}

export def "test generate-id returns different values on each call" [] {
  use ../utils.nu generate-id

  let id1 = generate-id
  let id2 = generate-id
  let id3 = generate-id

  assert ($id1 != $id2) "ID 1 and 2 should be different"
  assert ($id2 != $id3) "ID 2 and 3 should be different"
  assert ($id1 != $id3) "ID 1 and 3 should be different"
}

# --- Collision Detection Tests ---

export def "test generate-id with collision check avoids existing ids" [] {
  use ../utils.nu generate-id-checked

  # Create a mock existing IDs table
  let existing_ids = ["a1b2c3d4" "e5f6g7h8" "12345678"]

  # Generate an ID that avoids the existing ones
  let new_id = generate-id-checked {|id| $id not-in $existing_ids }

  assert ($new_id not-in $existing_ids) "Generated ID should not collide with existing"
  assert equal ($new_id | str length) 8 "ID should be 8 characters"
}

# --- Uniqueness Test (Statistical) ---

export def "test generate-id produces unique ids over 100 iterations" [] {
  use ../utils.nu generate-id

  let ids = 1..100 | each {|_| generate-id }
  let unique_ids = $ids | uniq

  assert equal ($unique_ids | length) 100 "All 100 IDs should be unique"
}
