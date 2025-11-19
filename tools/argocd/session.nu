# ArgoCD Session Management via CLI
# Handles authentication using argocd CLI and token management

# Get authenticated token for an instance
export def get-token [instance: record] {
  let ctx = ctx-name $instance
  
  if (is-valid $ctx $instance.server) {
    read-token $ctx
  } else {
    login $instance
    read-token $ctx
  }
}

# Check if session is valid
def is-valid [ctx: string, server: string] {
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
  
  mut args = [
    "login"
    $instance.server
    "--username" $instance.creds.username
    "--password" $instance.creds.password
    "--name" $ctx
  ]
  
  # Add insecure flag if TLS verification is disabled
  let skip_tls = $env.TLS_REJECT_UNAUTHORIZED? | default "1" | $in == "0"
  if $skip_tls {
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
    let config_path = $"($env.HOME)/.argocd/config"
    
    if not ($config_path | path exists) {
      error make { 
        msg: "ArgoCD config not found. Login may have failed." 
      }
    }
    
    let config = open $config_path | from yaml
    
    let context = $config.contexts? 
      | default [] 
      | where name == $ctx 
      | first?
    
    if ($context | is-empty) {
      error make { 
        msg: $"Context '($ctx)' not found in ArgoCD config" 
      }
    }
    
    $context.user.auth-token
  } catch {
    error make { 
      msg: $"Failed to read token: ($in.msg)" 
    }
  }
}

# Generate context name for instance
def ctx-name [instance: record] {
  $"argocd-($instance.namespace)"
}
