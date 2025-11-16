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

# Phase 1B: Non-Destructive Write Operations (10 tools)

# 8. kubectl_apply - Apply YAML manifest
export def kubectl-apply-schema [] {
    {
        name: "kubectl_apply"
        description: "Apply a Kubernetes YAML manifest from a string or file"
        inputSchema: {
            type: "object"
            properties: {
                manifest: {
                    type: "string"
                    description: "YAML manifest to apply"
                }
                filename: {
                    type: "string"
                    description: "Path to a YAML file to apply (optional - use either manifest or filename)"
                }
                namespace: (namespace-parameter)
                dryRun: {
                    type: "boolean"
                    description: "If true, only print the object that would be sent without sending it"
                    default: false
                }
                force: {
                    type: "boolean"
                    description: "If true, immediately remove resources from API and bypass graceful deletion"
                    default: false
                }
                context: (context-parameter)
            }
            required: []
        }
    }
}

# 9. kubectl_create - Create Kubernetes resources
export def kubectl-create-schema [] {
    {
        name: "kubectl_create"
        description: "Create Kubernetes resources using various methods (from file or using subcommands)"
        inputSchema: {
            type: "object"
            properties: {
                manifest: {
                    type: "string"
                    description: "YAML manifest to create resources from"
                }
                filename: {
                    type: "string"
                    description: "Path to a YAML file to create resources from"
                }
                namespace: (namespace-parameter)
                dryRun: {
                    type: "boolean"
                    description: "If true, only print the object that would be sent without sending it"
                    default: false
                }
                validate: {
                    type: "boolean"
                    description: "If true, validate resource schema against server schema"
                    default: true
                }
                context: (context-parameter)
            }
            required: []
        }
    }
}

# 10. kubectl_patch - Update resource fields
export def kubectl-patch-schema [] {
    {
        name: "kubectl_patch"
        description: "Update field(s) of a resource using strategic merge patch, JSON merge patch, or JSON patch"
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of resource to patch (e.g., pods, deployments, services)"
                }
                name: {
                    type: "string"
                    description: "Name of the resource to patch"
                }
                namespace: (namespace-parameter)
                patchType: {
                    type: "string"
                    description: "Type of patch to apply"
                    enum: ["strategic", "merge", "json"]
                    default: "strategic"
                }
                patchData: {
                    type: "object"
                    description: "Patch data as a JSON object"
                }
                patchFile: {
                    type: "string"
                    description: "Path to a file containing the patch data (alternative to patchData)"
                }
                dryRun: {
                    type: "boolean"
                    description: "If true, only print the object that would be sent"
                    default: false
                }
                context: (context-parameter)
            }
            required: ["resourceType", "name"]
        }
    }
}

# 11. kubectl_scale - Scale deployments/statefulsets
export def kubectl-scale-schema [] {
    {
        name: "kubectl_scale"
        description: "Scale a Kubernetes deployment"
        inputSchema: {
            type: "object"
            properties: {
                name: {
                    type: "string"
                    description: "Name of the deployment to scale"
                }
                namespace: (namespace-parameter)
                replicas: {
                    type: "number"
                    description: "Number of replicas to scale to"
                }
                resourceType: {
                    type: "string"
                    description: "Resource type to scale (deployment, replicaset, statefulset)"
                    default: "deployment"
                }
                context: (context-parameter)
            }
            required: ["name", "replicas"]
        }
    }
}

# 12. kubectl_rollout - Manage rollouts
export def kubectl-rollout-schema [] {
    {
        name: "kubectl_rollout"
        description: "Manage the rollout of a resource (e.g., deployment, daemonset, statefulset)"
        inputSchema: {
            type: "object"
            properties: {
                subCommand: {
                    type: "string"
                    description: "Rollout subcommand to execute"
                    enum: ["history", "pause", "restart", "resume", "status", "undo"]
                    default: "status"
                }
                resourceType: {
                    type: "string"
                    description: "Type of resource to manage rollout for"
                    enum: ["deployment", "daemonset", "statefulset"]
                    default: "deployment"
                }
                name: {
                    type: "string"
                    description: "Name of the resource"
                }
                namespace: (namespace-parameter)
                revision: {
                    type: "number"
                    description: "Revision to rollback to (for undo subcommand)"
                }
                toRevision: {
                    type: "number"
                    description: "Revision to roll back to (for history subcommand)"
                }
                timeout: {
                    type: "string"
                    description: "The length of time to wait before giving up (e.g., '30s', '1m', '2m30s')"
                }
                watch: {
                    type: "boolean"
                    description: "Watch the rollout status in real-time until completion"
                    default: false
                }
                context: (context-parameter)
            }
            required: ["subCommand", "resourceType", "name", "namespace"]
        }
    }
}

# 13. exec_in_pod - Execute command in pod
export def exec-in-pod-schema [] {
    {
        name: "exec_in_pod"
        description: "Execute a command in a Kubernetes pod or container and return the output"
        inputSchema: {
            type: "object"
            properties: {
                name: {
                    type: "string"
                    description: "Name of the pod to execute the command in"
                }
                namespace: (namespace-parameter)
                command: {
                    type: "string"
                    description: "Command to execute in the pod (string or array of args)"
                }
                container: {
                    type: "string"
                    description: "Container name (required when pod has multiple containers)"
                }
                shell: {
                    type: "string"
                    description: "Shell to use for command execution (e.g. '/bin/sh', '/bin/bash'). If not provided, will use command as-is."
                }
                timeout: {
                    type: "number"
                    description: "Timeout for command - 60000 milliseconds if not specified"
                }
                context: (context-parameter)
            }
            required: ["name", "command"]
        }
    }
}

# 14. port_forward - Forward local port to pod/service
export def port-forward-schema [] {
    {
        name: "port_forward"
        description: "Forward a local port to a port on a Kubernetes resource"
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Type of resource (pod, service, deployment)"
                }
                resourceName: {
                    type: "string"
                    description: "Name of the resource"
                }
                localPort: {
                    type: "number"
                    description: "Local port to forward from"
                }
                targetPort: {
                    type: "number"
                    description: "Target port on the resource"
                }
                namespace: {
                    type: "string"
                    description: "Namespace of the resource"
                }
                context: (context-parameter)
            }
            required: ["resourceType", "resourceName", "localPort", "targetPort"]
        }
    }
}

# 15. stop_port_forward - Stop port forwarding
export def stop-port-forward-schema [] {
    {
        name: "stop_port_forward"
        description: "Stop a port-forward process"
        inputSchema: {
            type: "object"
            properties: {
                id: {
                    type: "string"
                    description: "ID of the port-forward process to stop"
                }
            }
            required: ["id"]
        }
    }
}

# 16. install_helm_chart - Install Helm chart
export def install-helm-chart-schema [] {
    {
        name: "install_helm_chart"
        description: "Install a Helm chart with support for both standard and template-based installation"
        inputSchema: {
            type: "object"
            properties: {
                name: {
                    type: "string"
                    description: "Name of the Helm release"
                }
                chart: {
                    type: "string"
                    description: "Chart name (e.g., 'nginx') or path to chart directory"
                }
                namespace: (namespace-parameter)
                repo: {
                    type: "string"
                    description: "Helm repository URL (optional if using local chart path)"
                }
                values: {
                    type: "object"
                    description: "Custom values to override chart defaults"
                }
                valuesFile: {
                    type: "string"
                    description: "Path to values file (alternative to values object)"
                }
                useTemplate: {
                    type: "boolean"
                    description: "Use helm template + kubectl apply instead of helm install (bypasses auth issues)"
                    default: false
                }
                createNamespace: {
                    type: "boolean"
                    description: "Create namespace if it doesn't exist"
                    default: true
                }
                context: (context-parameter)
            }
            required: ["name", "chart", "namespace"]
        }
    }
}

# 17. upgrade_helm_chart - Upgrade Helm release
export def upgrade-helm-chart-schema [] {
    {
        name: "upgrade_helm_chart"
        description: "Upgrade an existing Helm chart release"
        inputSchema: {
            type: "object"
            properties: {
                name: {
                    type: "string"
                    description: "Name of the Helm release to upgrade"
                }
                chart: {
                    type: "string"
                    description: "Chart name or path to chart directory"
                }
                namespace: (namespace-parameter)
                repo: {
                    type: "string"
                    description: "Helm repository URL"
                }
                values: {
                    type: "object"
                    description: "Custom values to override chart defaults"
                }
                valuesFile: {
                    type: "string"
                    description: "Path to values file"
                }
                install: {
                    type: "boolean"
                    description: "If true, install the release if it doesn't exist"
                    default: false
                }
                context: (context-parameter)
            }
            required: ["name", "chart", "namespace"]
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

# Get Phase 1B non-destructive write tool schemas
export def get-non-destructive-schemas [] {
    [
        (kubectl-apply-schema)
        (kubectl-create-schema)
        (kubectl-patch-schema)
        (kubectl-scale-schema)
        (kubectl-rollout-schema)
        (exec-in-pod-schema)
        (port-forward-schema)
        (stop-port-forward-schema)
        (install-helm-chart-schema)
        (upgrade-helm-chart-schema)
    ]
}

# Get all tool schemas (Phase 1A + 1B)
export def get-all-schemas [] {
    (get-readonly-schemas) | append (get-non-destructive-schemas)
}
