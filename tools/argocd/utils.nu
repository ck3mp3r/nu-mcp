# ArgoCD HTTP API utility helpers

use session.nu

# Make an authenticated HTTP request to ArgoCD API
export def api-request [
  method: string # HTTP method (get, post, put, delete)
  path: string # API path (e.g., /api/v1/applications)
  instance: record # ArgoCD instance {namespace, server, creds}
  --body: any = null # Request body for POST/PUT
  --params: record = {} # Query parameters
] {
  # Get authenticated token via session module
  let token = session get-token $instance

  # Build URL
  let url = build-url $instance.server $path $params

  # Build headers
  let headers = {
    "Authorization": $"Bearer ($token)"
    "Content-Type": "application/json"
  }

  # Make HTTP call
  http-call $method $url $headers $body
}

# Build URL with query parameters
def build-url [server: string path: string params: record] {
  let query = if ($params | is-empty) {
    ""
  } else {
    $params
    | transpose k v
    | each {|r| $"($r.k)=($r.v | url encode)" }
    | str join "&"
    | $"?($in)"
  }

  $"($server)($path)($query)"
}

# HTTP call wrapper with TLS handling
def http-call [method: string url: string headers: record body: any] {
  let skip_tls = $env.TLS_REJECT_UNAUTHORIZED? | default "1" | $in == "0"
  let is_localhost = $url | str contains "localhost"
  let insecure = $skip_tls or $is_localhost

  try {
    match $method {
      "get" => {
        if $insecure {
          http get --headers $headers --insecure $url
        } else {
          http get --headers $headers $url
        }
      }
      "post" => {
        let content = if $body != null { $body | to json } else { "" }
        if $insecure {
          http post --headers $headers --insecure --content-type "application/json" $url $content
        } else {
          http post --headers $headers --content-type "application/json" $url $content
        }
      }
      "put" => {
        let content = if $body != null { $body | to json } else { "" }
        if $insecure {
          http put --headers $headers --insecure --content-type "application/json" $url $content
        } else {
          http put --headers $headers --content-type "application/json" $url $content
        }
      }
      "delete" => {
        if $insecure {
          http delete --headers $headers --insecure $url
        } else {
          http delete --headers $headers $url
        }
      }
      _ => {
        error make {msg: $"Unsupported HTTP method: ($method)"}
      }
    }
  } catch {|err|
    error make {msg: $"API request failed: ($err.msg)"}
  }
}
