# ArgoCD HTTP API utility helpers

# Get ArgoCD server URL from environment
# Supports both ARGOCD_BASE_URL (standard) and ARGOCD_SERVER (legacy)
export def get-server-url [] {
  # Try ARGOCD_BASE_URL first (standard), then fall back to ARGOCD_SERVER
  let url = ($env.ARGOCD_BASE_URL? | default ($env.ARGOCD_SERVER? | default ""))

  if ($url | is-empty) {
    error make {
      msg: "ARGOCD_BASE_URL environment variable is not set (e.g., https://argocd.example.com)"
    }
  }
  $url
}

# Get ArgoCD API token from environment
export def get-auth-token [] {
  let token = $env.ARGOCD_API_TOKEN? | default ""
  if ($token | is-empty) {
    error make {
      msg: "ARGOCD_API_TOKEN environment variable is not set"
    }
  }
  $token
}

# Check if TLS verification should be disabled
# Returns true if TLS_REJECT_UNAUTHORIZED is set to "0"
export def should-skip-tls-verification [] {
  let tls_setting = $env.TLS_REJECT_UNAUTHORIZED? | default "1"
  $tls_setting == "0"
}

# Make an authenticated HTTP request to ArgoCD API
export def api-request [
  method: string # HTTP method (get, post, put, delete)
  path: string # API path (e.g., /api/v1/applications)
  --body: any = null # Request body for POST/PUT
  --params: record = {} # Query parameters
] {
  let server = (get-server-url)
  let token = (get-auth-token)
  let skip_tls = (should-skip-tls-verification)

  # Build URL with query parameters
  let query_string = if ($params | is-empty) {
    ""
  } else {
    let pairs = (
      $params | transpose key value | each {|row|
        $"($row.key)=($row.value | url encode)"
      } | str join "&"
    )
    $"?($pairs)"
  }

  let url = $"($server)($path)($query_string)"

  let headers = {
    "Authorization": $"Bearer ($token)"
    "Content-Type": "application/json"
  }

  try {
    if $method == "get" {
      if $skip_tls {
        http get --headers $headers --insecure $url
      } else {
        http get --headers $headers $url
      }
    } else if $method == "post" {
      if ($body != null) {
        if $skip_tls {
          http post --headers $headers --insecure --content-type "application/json" $url ($body | to json)
        } else {
          http post --headers $headers --content-type "application/json" $url ($body | to json)
        }
      } else {
        if $skip_tls {
          http post --headers $headers --insecure $url
        } else {
          http post --headers $headers $url
        }
      }
    } else if $method == "put" {
      if ($body != null) {
        if $skip_tls {
          http put --headers $headers --insecure --content-type "application/json" $url ($body | to json)
        } else {
          http put --headers $headers --content-type "application/json" $url ($body | to json)
        }
      } else {
        if $skip_tls {
          http put --headers $headers --insecure $url
        } else {
          http put --headers $headers $url
        }
      }
    } else if $method == "delete" {
      if $skip_tls {
        http delete --headers $headers --insecure $url
      } else {
        http delete --headers $headers $url
      }
    } else {
      error make {
        msg: $"Unsupported HTTP method: ($method)"
      }
    }
  } catch {|err|
    error make {
      msg: $"ArgoCD API request failed: ($err.msg)"
    }
  }
}
