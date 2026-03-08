# Tests for validation utilities with v2 responses

use std/assert
use test_helpers.nu [ sample-v2-search-response ]

# =============================================================================
# Validation Tests for v2 Response Structure
# =============================================================================

export def "test validate-search-response accepts v2 fields" [] {
  use ../utils.nu validate_search_response

  let v2_response = sample-v2-search-response
  let result = validate_search_response $v2_response

  assert ($result.valid == true) "Should accept v2 response with trustScore and benchmarkScore"
}

export def "test validate-search-response checks v2 required fields" [] {
  use ../utils.nu validate_search_response

  # v2 response with trustScore and benchmarkScore
  let valid_v2 = {
    results: [
      {id: "/test/lib" title: "Test" trustScore: 8 benchmarkScore: 85.5}
    ]
  }

  let result = validate_search_response $valid_v2
  assert ($result.valid == true) "Should accept valid v2 response"
}

export def "test validate-search-response rejects missing required fields" [] {
  use ../utils.nu validate_search_response

  # Missing id field
  let invalid = {
    results: [
      {title: "Test" trustScore: 8 benchmarkScore: 85.5}
    ]
  }

  let result = validate_search_response $invalid
  assert ($result.valid == false) "Should reject response missing id field"
}
