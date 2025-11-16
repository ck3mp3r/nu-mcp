# Kubernetes MCP Tool - Resource Operations
# Implementations for kubectl_get, kubectl_describe

use utils.nu *

# kubectl_get - Get or list Kubernetes resources
export def kubectl-get [
    params: record
] {
    # Extract parameters
    let resource_type = $params.resourceType
    let name = $params.name? | default ""
    let namespace = $params.namespace? | default ""
    let all_namespaces = $params.allNamespaces? | default false
    let output = $params.output? | default "json"
    let label_selector = $params.labelSelector? | default ""
    let field_selector = $params.fieldSelector? | default ""
    let sort_by = $params.sortBy? | default ""
    let context = $params.context? | default ""
    
    # Build kubectl arguments
    mut args = ["get" $resource_type]
    
    # Add name if specified
    if $name != "" {
        $args = ($args | append $name)
    }
    
    # Add label selector
    if $label_selector != "" {
        $args = ($args | append ["--selector" $label_selector])
    }
    
    # Add field selector
    if $field_selector != "" {
        $args = ($args | append ["--field-selector" $field_selector])
    }
    
    # Add sort-by
    if $sort_by != "" {
        $args = ($args | append ["--sort-by" $sort_by])
    }
    
    # Execute kubectl command
    let result = run-kubectl $args --namespace $namespace --context $context --output $output --all-namespaces $all_namespaces
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Mask secrets if this is a secret resource
    let masked_result = if $resource_type == "secrets" or $resource_type == "secret" {
        mask-secrets $result
    } else {
        $result
    }
    
    # Format response
    format-tool-response $masked_result
}

# kubectl_describe - Describe a Kubernetes resource
export def kubectl-describe [
    params: record
] {
    # Extract parameters
    let resource_type = $params.resourceType
    let name = $params.name
    let namespace = $params.namespace? | default ""
    let all_namespaces = $params.allNamespaces? | default false
    let context = $params.context? | default ""
    
    # Build kubectl arguments
    let args = ["describe" $resource_type $name]
    
    # Execute kubectl command (describe outputs text, not JSON)
    let result = run-kubectl $args --namespace $namespace --context $context --output "text" --all-namespaces $all_namespaces
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Format response
    format-tool-response {
        resourceType: $resource_type
        name: $name
        namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
        description: $result
    }
}
# kubectl_apply - Apply YAML manifest
export def kubectl-apply [
    params: record
] {
    # Extract parameters
    let manifest = $params.manifest? | default ""
    let filename = $params.filename? | default ""
    let namespace = $params.namespace? | default ""
    let dry_run = $params.dryRun? | default false
    let force = $params.force? | default false
    let context = $params.context? | default ""
    
    # Validate that either manifest or filename is provided
    if $manifest == "" and $filename == "" {
        return (format-tool-response {
            error: "MissingParameter"
            message: "Either manifest or filename must be provided"
            isError: true
        } --error true)
    }
    
    # Build kubectl arguments
    mut args = ["apply"]
    
    # Add filename or use stdin for manifest
    if $filename != "" {
        $args = ($args | append ["-f" $filename])
    } else {
        $args = ($args | append ["-f" "-"])  # stdin
    }
    
    # Add dry-run if specified
    if $dry_run {
        $args = ($args | append "--dry-run=client")
    }
    
    # Add force if specified
    if $force {
        $args = ($args | append "--force")
    }
    
    # Execute kubectl command
    let result = if $manifest != "" {
        run-kubectl $args --stdin $manifest --namespace $namespace --context $context --output "json"
    } else {
        run-kubectl $args --namespace $namespace --context $context --output "json"
    }
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Format response
    format-tool-response {
        operation: "apply"
        result: $result
    }
}

# kubectl_create - Create Kubernetes resources
export def kubectl-create [
    params: record
] {
    # Extract parameters
    let manifest = $params.manifest? | default ""
    let filename = $params.filename? | default ""
    let namespace = $params.namespace? | default ""
    let dry_run = $params.dryRun? | default false
    let validate = $params.validate? | default true
    let context = $params.context? | default ""
    
    # Validate that either manifest or filename is provided
    if $manifest == "" and $filename == "" {
        return (format-tool-response {
            error: "MissingParameter"
            message: "Either manifest or filename must be provided"
            isError: true
        } --error true)
    }
    
    # Build kubectl arguments
    mut args = ["create"]
    
    # Add filename or use stdin for manifest
    if $filename != "" {
        $args = ($args | append ["-f" $filename])
    } else {
        $args = ($args | append ["-f" "-"])  # stdin
    }
    
    # Add dry-run if specified
    if $dry_run {
        $args = ($args | append "--dry-run=client")
    }
    
    # Add validate flag
    if not $validate {
        $args = ($args | append "--validate=false")
    }
    
    # Execute kubectl command
    let result = if $manifest != "" {
        run-kubectl $args --stdin $manifest --namespace $namespace --context $context --output "json"
    } else {
        run-kubectl $args --namespace $namespace --context $context --output "json"
    }
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Format response
    format-tool-response {
        operation: "create"
        result: $result
    }
}

# kubectl_patch - Update resource fields
export def kubectl-patch [
    params: record
] {
    # Extract parameters
    let resource_type = $params.resourceType
    let name = $params.name
    let namespace = $params.namespace? | default ""
    let patch_type = $params.patchType? | default "strategic"
    let patch_data = $params.patchData? | default null
    let patch_file = $params.patchFile? | default ""
    let dry_run = $params.dryRun? | default false
    let context = $params.context? | default ""
    
    # Validate that either patchData or patchFile is provided
    if $patch_data == null and $patch_file == "" {
        return (format-tool-response {
            error: "MissingParameter"
            message: "Either patchData or patchFile must be provided"
            isError: true
        } --error true)
    }
    
    # Build kubectl arguments
    mut args = ["patch" $resource_type $name]
    
    # Add patch type
    let patch_type_flag = match $patch_type {
        "strategic" => "--type=strategic"
        "merge" => "--type=merge"
        "json" => "--type=json"
        _ => "--type=strategic"
    }
    $args = ($args | append $patch_type_flag)
    
    # Add patch data
    if $patch_data != null {
        let patch_json = ($patch_data | to json --raw)
        $args = ($args | append ["--patch" $patch_json])
    } else {
        $args = ($args | append ["--patch-file" $patch_file])
    }
    
    # Add dry-run if specified
    if $dry_run {
        $args = ($args | append "--dry-run=client")
    }
    
    # Execute kubectl command
    let result = run-kubectl $args --namespace $namespace --context $context --output "json"
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Format response
    format-tool-response {
        operation: "patch"
        resourceType: $resource_type
        name: $name
        result: $result
    }
}
