# Core tmux utilities and helper functions

# Check if tmux is available
export def check_tmux [] {
  try {
    tmux -V | str trim
    true
  } catch {
    false
  }
}

# Helper function to execute tmux commands with logging (following k8s pattern)
export def exec_tmux_command [cmd_args: list<string>] {
  let full_cmd = (["tmux"] | append $cmd_args)
  print $"Executing: ($full_cmd | str join ' ')"
  run-external ...$full_cmd
}

# Helper function to resolve pane target (basic ID-based targeting)
# Advanced name/context resolution is handled in the calling functions
export def resolve_pane_target [session: string window?: string pane?: string] {
  # Build target using window/pane IDs
  mut target = $session
  if $window != null {
    $target = $"($target):($window)"
  }
  if $pane != null {
    if $window == null {
      $target = $"($target):"
    }
    $target = $"($target).($pane)"
  }
  return $target
}