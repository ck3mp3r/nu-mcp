# Tests for Context7 API client v2 endpoints

use std/assert
use nu-mimic *
use wrappers.nu *
use test_helpers.nu [ sample-v2-search-response sample-v2-context-response ]

# =============================================================================
# Search Libraries v2 Tests
# =============================================================================

export def --env "test search-libraries uses v2 endpoint with both params" [] {
  with-mimic {
    # v2 endpoint requires BOTH libraryName and query in URL
    let expected_url = "https://context7.com/api/v2/libs/search?libraryName=react&query=how+to+use+hooks"
    let mock_response = sample-v2-search-response

    # This mock will ONLY match if URL is exactly v2 format
    mimic register http-get {
      args: [$expected_url]
      returns: ($mock_response | to json)
    }

    use ../api.nu search_libraries

    # Try calling with v2 signature
    let result = search_libraries "react" "how to use hooks"

    # This should fail if using v1 endpoint (URL won't match mock)
    assert ($result.success == true) "Should succeed when using v2 endpoint"
  }
}

export def --env "test search-libraries response has v2 fields" [] {
  with-mimic {
    let expected_url = "https://context7.com/api/v2/libs/search?libraryName=react&query=hooks"
    let mock_response = sample-v2-search-response

    mimic register http-get {
      args: [$expected_url]
      returns: ($mock_response | to json)
    }

    use ../api.nu search_libraries
    let result = search_libraries "react" "hooks"

    assert ($result.success == true) "Should succeed"

    let first_result = $result.data.results | first
    assert ("trustScore" in $first_result) "Response should have trustScore field (v2)"
    assert ("benchmarkScore" in $first_result) "Response should have benchmarkScore field (v2)"
    assert (($first_result.trustScore | describe) == "int") "trustScore should be integer"
    assert (($first_result.benchmarkScore | describe) =~ "float|decimal") "benchmarkScore should be number"
  }
}

# =============================================================================
# Fetch Library Documentation v2 Tests
# =============================================================================

export def --env "test fetch-docs uses v2 context endpoint" [] {
  with-mimic {
    # v2 uses /v2/context with libraryId as query param, query is required
    let expected_url = "https://context7.com/api/v2/context?libraryId=facebook%2Freact&query=how+to+use+hooks&type=txt"
    let mock_response = sample-v2-context-response

    mimic register http-get {
      args: [$expected_url]
      returns: $mock_response
    }

    use ../api.nu fetch_library_documentation
    # v2 signature: fetch_library_documentation library_id query api_key
    let result = fetch_library_documentation "facebook/react" "how to use hooks"

    assert ($result.success == true) "Should succeed with v2 context endpoint"
  }
}
