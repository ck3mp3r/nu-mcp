# Tests for formatters with v2 response data

use std/assert
use test_helpers.nu [ sample-v2-search-response ]

# =============================================================================
# Formatter Tests for v2 Fields
# =============================================================================

export def "test format-search-result includes trustScore" [] {
  use ../formatters.nu format_search_result

  let result = {
    id: "/facebook/react"
    title: "React"
    description: "JavaScript library"
    trustScore: 10
    benchmarkScore: 98.5
  }

  let output = format_search_result $result

  assert ($output | str contains "Trust Score: 10") "Should display trustScore"
  assert ($output | str contains "Benchmark Score: 98.5") "Should display benchmarkScore"
}

export def "test format-search-results displays v2 fields" [] {
  use ../formatters.nu format_search_results

  let response = sample-v2-search-response
  let output = format_search_results $response

  assert ($output | str contains "Trust Score") "Should mention Trust Score in output"
  assert ($output | str contains "Benchmark Score") "Should mention Benchmark Score in output"
  assert ($output | str contains "/facebook/react") "Should display library ID"
}

export def "test format-search-result with missing optional fields" [] {
  use ../formatters.nu format_search_result

  # Minimal result with only required fields
  let result = {
    id: "/test/lib"
    title: "Test Library"
    description: "A test"
  }

  let output = format_search_result $result

  # Should not error on missing optional fields
  assert ($output | str contains "Test Library") "Should display title"
  assert ($output | str contains "/test/lib") "Should display ID"
}
