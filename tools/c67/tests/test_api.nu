# Tests for Context7 API client

use std/assert
use nu-mimic *
use wrappers.nu *

# =============================================================================
# Search Libraries Tests
# =============================================================================

export def --env "test search-libraries calls http correctly" [] {
  with-mimic {
    let expected_url = "https://context7.com/api/v2/libs/search?libraryName=react&query=how+to+use+hooks"
    let mock_response = {
      results: [
        {id: "/facebook/react" title: "React" trustScore: 10 benchmarkScore: 95.5}
      ]
    }
    
    mimic register http-get {
      args: [$expected_url {Content-Type: "application/json"}]
      returns: $mock_response
    }

    use ../api.nu search-libraries
    let result = search-libraries "react" "how to use hooks"
    
    assert ($result.success == true) "Should succeed"
    assert (($result.data.results | length) == 1) "Should return 1 result"
  }
}
