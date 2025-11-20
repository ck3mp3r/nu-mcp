# ArgoCD Session Management via CLI
# Handles authentication using argocd CLI and token management

# Get authenticated token for an instance
export def get-token [instance: record] {
  let ctx = ctx-name $instance

  # If creds is null, user has already logged in via argocd CLI
  # Just verify the session is valid and use existing token
  if $instance.creds == null {
    if not (is-valid $ctx $instance.server) {
      error make {msg: $"No valid argocd CLI session found for ($instance.server). Please login using: argocd login"}
    }
    return (read-token $ctx)
  }

  # Auto-discovery mode: login if needed
  if (is-valid $ctx $instance.server) {
    read-token $ctx
  } else {
    login $instance
    read-token $ctx
  }
}

# Check if session is valid
def is-valid [ctx: string server: string] {
  try {
    # Try to set context
    let context_result = (argocd context $ctx | complete)
    if $context_result.exit_code != 0 {
      return false
    }

    # Verify authentication with a simple API call
    let auth_result = (argocd account get-user-info --grpc-web | complete)
    $auth_result.exit_code == 0
  } catch {
    false
  }
}

# Login via ArgoCD CLI
def login [instance: record] {
  let ctx = ctx-name $instance

  # Strip https:// or http:// from server for argocd CLI
  let server = $instance.server | str replace --regex '^https?://' ''

  mut args = [
    "login"
    $server
    "--username"
    $instance.creds.username
    "--password"
    $instance.creds.password
    "--name"
    $ctx
  ]

  # Add insecure flag if TLS verification is disabled OR if using localhost
  let skip_tls = $env.MCP_INSECURE_TLS? | default "false" | $in == "true"
  let is_localhost = $instance.server | str contains "localhost"
  if $skip_tls or $is_localhost {
    $args = ($args | append "--insecure")
  }

  try {
    let result = (^argocd ...$args | complete)
    if $result.exit_code != 0 {
      error make {
        msg: $"Failed to login to ArgoCD: ($result.stderr)"
      }
    }
  } catch {
    error make {
      msg: $"Failed to login to ArgoCD: ($in.msg)"
    }
  }
}

# Read token from ArgoCD CLI config
def read-token [ctx: string] {
  try {
    let config_path = $"($env.HOME)/.config/argocd/config"

    if not ($config_path | path exists) {
      error make {
        msg: "ArgoCD config not found. Login may have failed."
      }
    }

    let config = open $config_path | from yaml

    let contexts = $config.contexts? | default []
    let matching_contexts = $contexts | where name == $ctx

    if ($matching_contexts | is-empty) {
      error make {
        msg: $"Context '($ctx)' not found in ArgoCD config"
      }
    }

    let context = $matching_contexts | first
    let user_name = $context.user

    # Look up the user's auth token
    let users = $config.users? | default []
    let matching_users = $users | where name == $user_name

    if ($matching_users | is-empty) {
      error make {
        msg: $"User '($user_name)' not found in ArgoCD config"
      }
    }

    let user = $matching_users | first
    $user.auth-token
  } catch {
    error make {
      msg: $"Failed to read token: ($in.msg)"
    }
  }
}

# Generate context name for instance
def ctx-name [instance: record] {
  # When using explicit server (namespace is null), use the server host as context name
  if $instance.namespace == null {
    $instance.server | str replace --regex '^https?://' ''
  } else if ($instance.server | str contains "localhost") {
    # For port-forwarded localhost, use the server URL as context
    $instance.server | str replace --regex '^https?://' ''
  } else {
    $"argocd-($instance.namespace)"
  }
}
