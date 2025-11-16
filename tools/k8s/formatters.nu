# Kubernetes MCP Tool - Tool Schema Definitions
# MCP tool schemas for all k8s operations

# Common parameter definitions
export def namespace-parameter [] {
    {
        type: "string"
        description: "Kubernetes namespace (optional - defaults to KUBE_NAMESPACE env var or 'default')"
    }
}

export def context-parameter [] {
    {
        type: "string"
        description: "Kubernetes context to use (optional - defaults to KUBE_CONTEXT env var or current context)"
    }
}

# Phase 1A: Read-Only Tools (7 tools)

# 1. kubectl_get - Get/list Kubernetes resources
export def kubectl-get-schema [] {
    {
        name: "kubectl_get"
        description: "Get or list Kubernetes resources by resource type, name, and optionally namespace"
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of resource to get (e.g., pods, deployments, services, configmaps, events, etc.)"
                }
                name: {
                    type: "string"
                    description: "Name of the resource (optional - if not provided, lists all resources of the specified type)"
                }
                namespace: (namespace-parameter)
                allNamespaces: {
                    type: "boolean"
                    description: "If true, list resources across all namespaces"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["json", "yaml", "wide", "name"]
                    description: "Output format"
                    default: "json"
                }
                labelSelector: {
                    type: "string"
                    description: "Filter resources by label selector (e.g. 'app=nginx')"
                }
                fieldSelector: {
                    type: "string"
                    description: "Filter resources by field selector (e.g. 'metadata.name=my-pod')"
                }
                sortBy: {
                    type: "string"
                    description: "Sort events by a field (default: lastTimestamp). Only applicable for events."
                }
                context: (context-parameter)
            }
            required: ["resourceType"]
        }
    }
}

# 2. kubectl_describe - Describe Kubernetes resource
export def kubectl-describe-schema [] {
    {
        name: "kubectl_describe"
        description: "Describe Kubernetes resources by resource type, name, and optionally namespace"
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of resource to describe (e.g., pods, deployments, services, etc.)"
                }
                name: {
                    type: "string"
                    description: "Name of the resource to describe"
                }
                namespace: (namespace-parameter)
                allNamespaces: {
                    type: "boolean"
                    description: "If true, describe resources across all namespaces"
                    default: false
                }
                context: (context-parameter)
            }
            required: ["resourceType", "name"]
        }
    }
}

# 3. kubectl_logs - Get pod/container logs
export def kubectl-logs-schema [] {
    {
        name: "kubectl_logs"
        description: "Get logs from Kubernetes resources like pods, deployments, or jobs"
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of resource to get logs from"
                    default: "pod"
                }
                name: {
                    type: "string"
                    description: "Name of the resource"
                }
                namespace: (namespace-parameter)
                container: {
                    type: "string"
                    description: "Container name (required when pod has multiple containers)"
                }
                tail: {
                    type: "integer"
                    description: "Number of lines to show from end of logs"
                }
                since: {
                    type: "string"
                    description: "Show logs since relative time (e.g. '5s', '2m', '3h')"
                }
                sinceTime: {
                    type: "string"
                    description: "Show logs since absolute time (RFC3339)"
                }
                timestamps: {
                    type: "boolean"
                    description: "Include timestamps in logs"
                    default: false
                }
                previous: {
                    type: "boolean"
                    description: "Include logs from previously terminated containers"
                    default: false
                }
                follow: {
                    type: "boolean"
                    description: "Follow logs output (not recommended, may cause timeouts)"
                    default: false
                }
                labelSelector: {
                    type: "string"
                    description: "Filter resources by label selector"
                }
                context: (context-parameter)
            }
            required: ["name"]
        }
    }
}

# 4. kubectl_context - Manage kubectl contexts
export def kubectl-context-schema [] {
    {
        name: "kubectl_context"
        description: "Manage Kubernetes contexts - list, get, or set the current context"
        inputSchema: {
            type: "object"
            properties: {
                operation: {
                    type: "string"
                    enum: ["list", "get", "set"]
                    description: "Operation to perform: list contexts, get current context, or set current context"
                    default: "list"
                }
                name: {
                    type: "string"
                    description: "Name of the context to set as current (required for set operation)"
                }
                showCurrent: {
                    type: "boolean"
                    description: "When listing contexts, highlight which one is currently active"
                    default: true
                }
                detailed: {
                    type: "boolean"
                    description: "Include detailed information about the context"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["json", "yaml", "name", "custom"]
                    description: "Output format"
                    default: "json"
                }
            }
            required: ["operation"]
        }
    }
}

# 5. explain_resource - Explain Kubernetes resource schema
export def explain-resource-schema [] {
    {
        name: "explain_resource"
        description: "Get documentation for a Kubernetes resource or field"
        inputSchema: {
            type: "object"
            properties: {
                resource: {
                    type: "string"
                    description: "Resource name or field path (e.g. 'pods' or 'pods.spec.containers')"
                }
                apiVersion: {
                    type: "string"
                    description: "API version to use (e.g. 'apps/v1')"
                }
                recursive: {
                    type: "boolean"
                    description: "Print the fields of fields recursively"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["plaintext", "plaintext-openapiv2"]
                    description: "Output format (plaintext or plaintext-openapiv2)"
                    default: "plaintext"
                }
                context: (context-parameter)
            }
            required: ["resource"]
        }
    }
}

# 6. list_api_resources - List available Kubernetes API resources
export def list-api-resources-schema [] {
    {
        name: "list_api_resources"
        description: "List the API resources available in the cluster"
        inputSchema: {
            type: "object"
            properties: {
                apiGroup: {
                    type: "string"
                    description: "API group to filter by"
                }
                namespaced: {
                    type: "boolean"
                    description: "If true, only show namespaced resources"
                }
                verbs: {
                    type: "array"
                    items: {
                        type: "string"
                    }
                    description: "List of verbs to filter by"
                }
                output: {
                    type: "string"
                    enum: ["wide", "name", "no-headers"]
                    description: "Output format (wide, name, or no-headers)"
                    default: "wide"
                }
                context: (context-parameter)
            }
            required: []
        }
    }
}

# 7. ping - Verify kubectl connectivity
export def ping-schema [] {
    {
        name: "ping"
        description: "Verify that the counterpart is still responsive and the connection is alive."
        inputSchema: {
            type: "object"
            properties: {}
            required: []
        }
    }
}

# Get all Phase 1A read-only tool schemas
export def get-readonly-schemas [] {
    [
        (kubectl-get-schema)
        (kubectl-describe-schema)
        (kubectl-logs-schema)
        (kubectl-context-schema)
        (explain-resource-schema)
        (list-api-resources-schema)
        (ping-schema)
    ]
}

# Get all tool schemas (currently just Phase 1A)
export def get-all-schemas [] {
    get-readonly-schemas
}
