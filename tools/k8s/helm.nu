# Kubernetes MCP Tool - Helm Operations
# Implementations for install_helm_chart, upgrade_helm_chart

use utils.nu *

# install_helm_chart - Install Helm chart
export def install-helm-chart [
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
    
    # Add values from object if specified
    if $values != null {
        # Convert values object to YAML and use --set-json
        let values_json = ($values | to json --raw)
        $args = ($args | append ["--set-json" $values_json])
    }
    
    # Execute helm command
    let result = try {
        let output = (^helm ...$args)
        {
            success: true
            output: $output
        }
    } catch {
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

# upgrade_helm_chart - Upgrade Helm release
export def upgrade-helm-chart [
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
    
    # Add values from object if specified
    if $values != null {
        # Convert values object to YAML and use --set-json
        let values_json = ($values | to json --raw)
        $args = ($args | append ["--set-json" $values_json])
    }
    
    # Execute helm command
    let result = try {
        let output = (^helm ...$args)
        {
            success: true
            output: $output
        }
    } catch {
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
