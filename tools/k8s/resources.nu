# Kubernetes MCP Tool - Resource Operations
# Implementations for kubectl_get, kubectl_describe

use utils.nu *

# kubectl_get - Get or list Kubernetes resources
export def kubectl-get [
    params: record
] -> record {
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
        return (format-tool-response $result --error)
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
] -> record {
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
        return (format-tool-response $result --error)
    }
    
    # Format response
    format-tool-response {
        resourceType: $resource_type
        name: $name
        namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
        description: $result
    }
}
