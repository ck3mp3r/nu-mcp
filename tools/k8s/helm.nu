# Kubernetes MCP Tool - Helm Operations
# Implementations for helm_install, helm_upgrade, helm_uninstall

use utils.nu *

# helm_install - Install Helm chart
export def helm-install [
  params: record
] {
  # Extract parameters
  let name = $params.name
  let chart = $params.chart
  let namespace = $params.namespace
  let repo = $params.repo? | default ""
  let values = $params.values? | default null
  let values_file = $params.valuesFile? | default ""
  let use_template = $params.useTemplate? | default false
  let create_namespace = $params.createNamespace? | default true
  let context = $params.context? | default ""

  # Build helm command arguments
  mut args = ["install" $name $chart]

  # Add namespace
  $args = ($args | append ["--namespace" $namespace])

  # Add create-namespace flag
  if $create_namespace {
    $args = ($args | append "--create-namespace")
  }

  # Add repository if specified
  if $repo != "" {
    $args = ($args | append ["--repo" $repo])
  }

  # Add values file if specified
  if $values_file != "" {
    $args = ($args | append ["--values" $values_file])
  }

  # Add values from object if specified (write to temp file)
  let temp_values_file = if $values != null {
    let temp_file = $"/tmp/helm-values-(date now | format date '%s').yaml"
    $values | to yaml | save -f $temp_file
    $args = ($args | append ["--values" $temp_file])
    $temp_file
  } else {
    ""
  }

  # Execute helm command
  let result = try {
    let output = (^helm ...$args)

    # Clean up temp values file if it exists
    if $temp_values_file != "" {
      try { rm -f $temp_values_file } catch { }
    }

    {
      success: true
      output: $output
    }
  } catch {
    # Clean up temp values file if it exists
    if $temp_values_file != "" {
      try { rm -f $temp_values_file } catch { }
    }

    {
      error: "HelmInstallFailed"
      message: ($in | str trim)
      isError: true
    }
  }

  # Check for errors
  if ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "install"
    release: $name
    chart: $chart
    namespace: $namespace
    result: ($result | get output)
  }
}

# helm_upgrade - Upgrade Helm release
export def helm-upgrade [
  params: record
] {
  # Extract parameters
  let name = $params.name
  let chart = $params.chart
  let namespace = $params.namespace
  let repo = $params.repo? | default ""
  let values = $params.values? | default null
  let values_file = $params.valuesFile? | default ""
  let install = $params.install? | default false
  let context = $params.context? | default ""

  # Build helm command arguments
  mut args = ["upgrade" $name $chart]

  # Add namespace
  $args = ($args | append ["--namespace" $namespace])

  # Add install flag if specified
  if $install {
    $args = ($args | append "--install")
  }

  # Add repository if specified
  if $repo != "" {
    $args = ($args | append ["--repo" $repo])
  }

  # Add values file if specified
  if $values_file != "" {
    $args = ($args | append ["--values" $values_file])
  }

  # Add values from object if specified (write to temp file)
  let temp_values_file = if $values != null {
    let temp_file = $"/tmp/helm-values-(date now | format date '%s').yaml"
    $values | to yaml | save -f $temp_file
    $args = ($args | append ["--values" $temp_file])
    $temp_file
  } else {
    ""
  }

  # Execute helm command
  let result = try {
    let output = (^helm ...$args)

    # Clean up temp values file if it exists
    if $temp_values_file != "" {
      try { rm -f $temp_values_file } catch { }
    }

    {
      success: true
      output: $output
    }
  } catch {
    # Clean up temp values file if it exists
    if $temp_values_file != "" {
      try { rm -f $temp_values_file } catch { }
    }

    {
      error: "HelmUpgradeFailed"
      message: ($in | str trim)
      isError: true
    }
  }

  # Check for errors
  if ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "upgrade"
    release: $name
    chart: $chart
    namespace: $namespace
    result: ($result | get output)
  }
}

# helm_uninstall - Uninstall Helm release
export def helm-uninstall [
  params: record
] {
  # Extract parameters
  let name = $params.name
  let namespace = $params.namespace
  let context = $params.context? | default ""

  # Build helm command arguments
  let args = ["uninstall" $name "--namespace" $namespace]

  # Execute helm command
  let result = try {
    let output = (^helm ...$args)
    {
      success: true
      output: $output
    }
  } catch {
    {
      error: "HelmUninstallFailed"
      message: ($in | str trim)
      isError: true
    }
  }

  # Check for errors
  if ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
  }

  # Format response
  format-tool-response {
    operation: "uninstall"
    release: $name
    namespace: $namespace
    result: ($result | get output)
  }
}
