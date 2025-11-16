# Kubernetes MCP Tool - Operations
# Implementations for kubectl_logs, kubectl_context, explain_resource, list_api_resources, ping

use utils.nu *

# kubectl_logs - Get pod/container logs
export def kubectl-logs [
    params: record
] {
    # Extract parameters
    let resource_type = $params.resourceType? | default "pod"
    let name = $params.name
    let namespace = $params.namespace? | default ""
    let container = $params.container? | default ""
    let tail = $params.tail? | default null
    let since = $params.since? | default ""
    let since_time = $params.sinceTime? | default ""
    let timestamps = $params.timestamps? | default false
    let previous = $params.previous? | default false
    let follow = $params.follow? | default false
    let label_selector = $params.labelSelector? | default ""
    let context = $params.context? | default ""
    
    # Build kubectl arguments
    mut args = ["logs"]
    
    # Add resource type and name (or label selector)
    if $label_selector != "" {
        $args = ($args | append ["--selector" $label_selector])
    } else {
        if $resource_type != "pod" {
            $args = ($args | append $"($resource_type)/($name)")
        } else {
            $args = ($args | append $name)
        }
    }
    
    # Add container if specified
    if $container != "" {
        $args = ($args | append ["--container" $container])
    }
    
    # Add tail
    if $tail != null {
        $args = ($args | append ["--tail" ($tail | into string)])
    }
    
    # Add since
    if $since != "" {
        $args = ($args | append ["--since" $since])
    }
    
    # Add since-time
    if $since_time != "" {
        $args = ($args | append ["--since-time" $since_time])
    }
    
    # Add timestamps
    if $timestamps {
        $args = ($args | append "--timestamps")
    }
    
    # Add previous
    if $previous {
        $args = ($args | append "--previous")
    }
    
    # Add follow (note: this is problematic for MCP as it's streaming)
    if $follow {
        $args = ($args | append "--follow")
    }
    
    # Execute kubectl command (logs are plain text)
    let result = run-kubectl $args --namespace $namespace --context $context --output "text"
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Format response
    format-tool-response {
        resourceType: $resource_type
        name: $name
        namespace: (if $namespace != "" { $namespace } else { get-default-namespace })
        container: $container
        logs: $result
    }
}

# kubectl_context - Manage kubectl contexts
export def kubectl-context [
    params: record
] {
    # Extract parameters
    let operation = $params.operation
    let name = $params.name? | default ""
    let show_current = $params.showCurrent? | default true
    let detailed = $params.detailed? | default false
    let output = $params.output? | default "json"
    
    # Handle different operations
    match $operation {
        "list" => {
            # List all contexts
            let contexts = list-contexts
            
            if $output == "json" {
                format-tool-response {
                    operation: "list"
                    contexts: $contexts
                    current: (get-current-context)
                }
            } else {
                format-tool-response {
                    operation: "list"
                    output: $contexts
                }
            }
        },
        "get" => {
            # Get current context
            let current = get-current-context
            
            if $current == "" {
                return (format-tool-response {
                    error: "NoContextSet"
                    message: "No current context is set"
                    isError: true
                } --error true)
            }
            
            format-tool-response {
                operation: "get"
                current: $current
                namespace: (get-default-namespace)
            }
        },
        "use" | "set" => {
            # Switch context (use and set are aliases)
            if $name == "" {
                return (format-tool-response {
                    error: "MissingParameter"
                    message: "Context name is required for 'set' operation"
                    isError: true
                } --error true)
            }
            
            # Execute context switch
            let result = try {
                ^kubectl config use-context $name | complete
            } catch {
                {
                    error: "ContextSwitchFailed"
                    message: $"Failed to switch to context '($name)'"
                    isError: true
                }
            }
            
            if ($result | get exit_code) == 0 {
                format-tool-response {
                    operation: $operation
                    previous: (get-current-context)
                    current: $name
                    message: $"Switched to context '($name)'"
                }
            } else {
                format-tool-response {
                    error: "ContextSwitchFailed"
                    message: ($result | get stderr | str trim)
                    isError: true
                } --error true
            }
        },
        _ => {
            format-tool-response {
                error: "InvalidOperation"
                message: $"Unknown operation: ($operation). Valid operations are: list, get, use"
                isError: true
            } --error true
        }
    }
}

# explain_resource - Explain Kubernetes resource schema
export def explain-resource [
    params: record
] {
    # Extract parameters
    let resource = $params.resource
    let api_version = $params.apiVersion? | default ""
    let recursive = $params.recursive? | default false
    let output = $params.output? | default "plaintext"
    let context = $params.context? | default ""
    
    # Build kubectl arguments
    mut args = ["explain" $resource]
    
    # Add API version
    if $api_version != "" {
        $args = ($args | append ["--api-version" $api_version])
    }
    
    # Add recursive
    if $recursive {
        $args = ($args | append "--recursive")
    }
    
    # Add output format
    if $output != "plaintext" {
        $args = ($args | append ["--output" $output])
    }
    
    # Execute kubectl command
    let result = run-kubectl $args --context $context --output "text"
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Format response
    format-tool-response {
        resource: $resource
        apiVersion: $api_version
        explanation: $result
    }
}

# list_api_resources - List available API resources
export def list-api-resources [
    params: record
] {
    # Extract parameters
    let api_group = $params.apiGroup? | default ""
    let namespaced = $params.namespaced? | default null
    let verbs = $params.verbs? | default []
    let output = $params.output? | default "json"
    let context = $params.context? | default ""
    
    # Build kubectl arguments
    mut args = ["api-resources"]
    
    # Add API group filter
    if $api_group != "" {
        $args = ($args | append ["--api-group" $api_group])
    }
    
    # Add namespaced filter
    if $namespaced != null {
        if $namespaced {
            $args = ($args | append "--namespaced=true")
        } else {
            $args = ($args | append "--namespaced=false")
        }
    }
    
    # Add verbs filter
    if ($verbs | length) > 0 {
        $args = ($args | append ["--verbs" ($verbs | str join ",")])
    }
    
    # Add output format
    if $output == "json" {
        $args = ($args | append ["--output" "wide"])
    } else {
        $args = ($args | append ["--output" $output])
    }
    
    # Execute kubectl command
    let result = run-kubectl $args --context $context --output "text"
    
    # Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # Parse the wide output into structured data if JSON requested
    if $output == "json" {
        let resources = $result 
            | lines 
            | skip 1  # Skip header
            | each {|line|
                let parts = $line | split row --regex '\s+' 
                {
                    name: ($parts | get 0)
                    shortnames: ($parts | get 1)
                    apiversion: ($parts | get 2)
                    namespaced: ($parts | get 3)
                    kind: ($parts | get 4)
                    verbs: (if ($parts | length) > 5 { $parts | get 5 } else { "" })
                }
            }
        
        format-tool-response {
            apiGroup: $api_group
            resources: $resources
        }
    } else {
        format-tool-response {
            output: $result
        }
    }
}

# ping - Verify kubectl connectivity
export def ping [
    params: record
] {
    # Extract parameters
    let context = $params.context? | default ""
    
    # Validate kubectl access
    let validation = validate-kubectl-access
    
    # Check if validation failed
    if ($validation | get isError? | default false) {
        return (format-tool-response $validation --error true)
    }
    
    # Get cluster info
    let cluster_info = try {
        let info = ^kubectl cluster-info | complete
        if ($info | get exit_code) == 0 {
            $info | get stdout | str trim
        } else {
            "Unable to retrieve cluster info"
        }
    } catch {
        "Unable to retrieve cluster info"
    }
    
    # Return success with details
    format-tool-response {
        status: "connected"
        kubectl: {
            version: (get-kubectl-version)
            path: (which kubectl | get path | first)
        }
        cluster: {
            context: (get-current-context)
            namespace: (get-default-namespace)
            info: $cluster_info
        }
        safetyMode: (get-safety-mode)
    }
}
