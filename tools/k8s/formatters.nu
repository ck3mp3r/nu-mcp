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
        description: "Get or list Kubernetes resources by type, name, and namespace. Returns structured JSON data for resources like pods, deployments, services, configmaps, secrets, etc."
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of Kubernetes resource (e.g., 'pods', 'deployments', 'services', 'configmaps', 'secrets', 'nodes', 'namespaces')"
                }
                name: {
                    type: "string"
                    description: "Name of the specific resource (optional - if omitted, lists all resources of the specified type)"
                }
                namespace: (namespace-parameter)
                allNamespaces: {
                    type: "boolean"
                    description: "If true, list resources across all namespaces (optional - default: false)"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["json", "yaml", "wide", "name"]
                    description: "Output format (optional - default: 'json')"
                    default: "json"
                }
                labelSelector: {
                    type: "string"
                    description: "Filter resources by label selector (optional - e.g., 'app=nginx,tier=frontend')"
                }
                fieldSelector: {
                    type: "string"
                    description: "Filter resources by field selector (optional - e.g., 'status.phase=Running')"
                }
                sortBy: {
                    type: "string"
                    description: "Sort results by field (optional - e.g., '.metadata.creationTimestamp')"
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
        description: "Show detailed information about a specific Kubernetes resource, including status, events, and configuration. Provides human-readable description with more context than 'get'."
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of Kubernetes resource (e.g., 'pod', 'deployment', 'service', 'node')"
                }
                name: {
                    type: "string"
                    description: "Name of the resource to describe"
                }
                namespace: (namespace-parameter)
                allNamespaces: {
                    type: "boolean"
                    description: "If true, search across all namespaces (optional - default: false)"
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
        description: "Retrieve logs from a pod or specific container. Supports options for tailing, timestamps, and viewing previous container logs (useful for debugging crashed containers)."
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Resource type (typically 'pod' or 'deployment')"
                    default: "pod"
                }
                name: {
                    type: "string"
                    description: "Name of the pod or deployment"
                }
                namespace: (namespace-parameter)
                container: {
                    type: "string"
                    description: "Container name (required if pod has multiple containers)"
                }
                tail: {
                    type: "integer"
                    description: "Number of lines to show from the end of logs (optional - e.g., 100)"
                }
                since: {
                    type: "string"
                    description: "Return logs newer than a relative duration (e.g., '5m', '1h', '2d')"
                }
                sinceTime: {
                    type: "string"
                    description: "Return logs after a specific time (RFC3339 format)"
                }
                timestamps: {
                    type: "boolean"
                    description: "Include timestamps in log output (optional - default: false)"
                    default: false
                }
                previous: {
                    type: "boolean"
                    description: "Get logs from previous container instance (useful for crashed containers)"
                    default: false
                }
                follow: {
                    type: "boolean"
                    description: "Stream logs in real-time (optional - default: false)"
                    default: false
                }
                labelSelector: {
                    type: "string"
                    description: "Select pods by label (e.g., 'app=nginx')"
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
        description: "Manage Kubernetes contexts from kubeconfig. List available contexts, get current context, or switch to a different context. Contexts define which cluster, user, and namespace to use."
        inputSchema: {
            type: "object"
            properties: {
                operation: {
                    type: "string"
                    enum: ["list", "get", "use"]
                    description: "Operation to perform: 'list' (show all contexts), 'get' (show current context), 'use' (switch context)"
                }
                name: {
                    type: "string"
                    description: "Context name (required for 'use' operation)"
                }
                showCurrent: {
                    type: "boolean"
                    description: "Highlight current context in list output (optional - default: true)"
                    default: true
                }
                detailed: {
                    type: "boolean"
                    description: "Show detailed context information including cluster, user, and namespace (optional - default: false)"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["json", "yaml", "table"]
                    description: "Output format (optional - default: 'json')"
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
        description: "Get documentation for Kubernetes resource types and their fields. Useful for understanding resource schemas, required fields, and API structure. Supports recursive exploration of nested fields."
        inputSchema: {
            type: "object"
            properties: {
                resource: {
                    type: "string"
                    description: "Resource type or field path to explain (e.g., 'pod', 'deployment.spec', 'pod.spec.containers')"
                }
                apiVersion: {
                    type: "string"
                    description: "API version to use (optional - e.g., 'v1', 'apps/v1')"
                }
                recursive: {
                    type: "boolean"
                    description: "Show all fields recursively (optional - default: false)"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["plaintext", "plaintext-openapiv2"]
                    description: "Output format (optional - default: 'plaintext')"
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
        description: "List all available Kubernetes API resource types in the cluster. Shows resource names, short names, API groups, namespaced status, and supported verbs (get, list, create, delete, etc.). Useful for discovering what resources are available."
        inputSchema: {
            type: "object"
            properties: {
                apiGroup: {
                    type: "string"
                    description: "Filter by API group (optional - e.g., 'apps', 'batch', 'networking.k8s.io')"
                }
                namespaced: {
                    type: "boolean"
                    description: "Filter by namespaced resources (optional - true for namespaced, false for cluster-scoped)"
                }
                verbs: {
                    type: "array"
                    items: {
                        type: "string"
                    }
                    description: "Filter by supported verbs (optional - e.g., ['list', 'get', 'create'])"
                }
                output: {
                    type: "string"
                    enum: ["wide", "name", "json"]
                    description: "Output format (optional - default: 'json')"
                    default: "json"
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
        description: "Verify connectivity to the Kubernetes cluster. Checks if kubectl is installed, configured correctly, and can reach the cluster. Returns cluster info, kubectl version, current context, and default namespace."
        inputSchema: {
            type: "object"
            properties: {
                context: (context-parameter)
            }
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
