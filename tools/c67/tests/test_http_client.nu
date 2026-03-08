# Tests for HTTP client wrapper functions

use std/assert
use nu-mimic *
use wrappers.nu *

# =============================================================================
# HTTP Wrapper Tests  
# =============================================================================

export def --env "test http-get can be mocked" [] {
  with-mimic {
    mimic register http-get {
      args: ['https://example.com' {}]
      returns: '{"test": "data"}'
    }

    let result = http-get 'https://example.com' {}
    
    assert equal $result '{"test": "data"}' "Should return mocked response"
  }
}

export def --env "test http-get with headers" [] {
  with-mimic {
    let mock_headers = {"Content-Type": "application/json"}
    
    mimic register http-get {
      args: ['https://example.com' $mock_headers]
      returns: '{"authenticated": true}'
    }

    let result = http-get 'https://example.com' $mock_headers
    
    assert equal $result '{"authenticated": true}' "Should return mocked authenticated response"
  }
}
