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

export def delegate-parameter [] {
  {
    type: "boolean"
    description: "If true, return the kubectl command string instead of executing it. Useful for delegation to other tools like tmux."
    default: false
  }
}

# 1. kube_get - Get/list Kubernetes resources
export def kubectl-get-schema [] {
  {
    name: "kube_get"
    description: "Get or list Kubernetes resources by resource type, name, and optionally namespace"
    input_schema: {
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
          enum: ["json" "yaml" "wide" "name"]
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
        delegate: (delegate-parameter)
      }
      required: ["resourceType"]
    }
  }
}

# 2. kube_describe - Describe Kubernetes resource
export def kubectl-describe-schema [] {
  {
    name: "kube_describe"
    description: "Describe Kubernetes resources by resource type, name, and optionally namespace"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["resourceType" "name"]
    }
  }
}

# 3. kube_logs - Get pod/container logs
export def kubectl-logs-schema [] {
  {
    name: "kube_logs"
    description: "Get logs from Kubernetes resources like pods, deployments, or jobs"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["name"]
    }
  }
}

# 4. kube_context - Manage kubectl contexts
export def kubectl-context-schema [] {
  {
    name: "kube_context"
    description: "Manage Kubernetes contexts - list, get, or set the current context"
    input_schema: {
      type: "object"
      properties: {
        operation: {
          type: "string"
          enum: ["list" "get" "set"]
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
          enum: ["json" "yaml" "name" "custom"]
          description: "Output format"
          default: "json"
        }
      }
      required: ["operation"]
    }
  }
}

# 5. kube_explain - Explain Kubernetes resource schema
export def explain-resource-schema [] {
  {
    name: "kube_explain"
    description: "Get documentation for a Kubernetes resource or field"
    input_schema: {
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
          enum: ["plaintext" "plaintext-openapiv2"]
          description: "Output format (plaintext or plaintext-openapiv2)"
          default: "plaintext"
        }
        context: (context-parameter)
        delegate: (delegate-parameter)
      }
      required: ["resource"]
    }
  }
}

# 6. kube_api_resources - List available Kubernetes API resources
export def list-api-resources-schema [] {
  {
    name: "kube_api_resources"
    description: "List the API resources available in the cluster"
    input_schema: {
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
          enum: ["wide" "name" "no-headers"]
          description: "Output format (wide, name, or no-headers)"
          default: "wide"
        }
        context: (context-parameter)
        delegate: (delegate-parameter)
      }
      required: []
    }
  }
}

# 7. ping - Verify kubectl connectivity
export def ping-schema [] {
  {
    name: "kube_ping"
    description: "Verify that the counterpart is still responsive and the connection is alive."
    input_schema: {
      type: "object"
      properties: {}
      required: []
    }
  }
}

# 8. kube_apply - Apply YAML manifest
export def kubectl-apply-schema [] {
  {
    name: "kube_apply"
    description: "Apply a Kubernetes YAML manifest from a string or file"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: []
    }
  }
}

# 9. kube_create - Create Kubernetes resources
export def kubectl-create-schema [] {
  {
    name: "kube_create"
    description: "Create Kubernetes resources using various methods (from file or using subcommands)"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: []
    }
  }
}

# 10. kube_patch - Update resource fields
export def kubectl-patch-schema [] {
  {
    name: "kube_patch"
    description: "Update field(s) of a resource using strategic merge patch, JSON merge patch, or JSON patch"
    input_schema: {
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
          enum: ["strategic" "merge" "json"]
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
        delegate: (delegate-parameter)
      }
      required: ["resourceType" "name"]
    }
  }
}

# 11. kube_scale - Scale deployments/statefulsets
export def kubectl-scale-schema [] {
  {
    name: "kube_scale"
    description: "Scale a Kubernetes deployment"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["name" "replicas"]
    }
  }
}

# 12. kube_rollout - Manage rollouts
export def kubectl-rollout-schema [] {
  {
    name: "kube_rollout"
    description: "Manage the rollout of a resource (e.g., deployment, daemonset, statefulset)"
    input_schema: {
      type: "object"
      properties: {
        subCommand: {
          type: "string"
          description: "Rollout subcommand to execute"
          enum: ["history" "pause" "restart" "resume" "status" "undo"]
          default: "status"
        }
        resourceType: {
          type: "string"
          description: "Type of resource to manage rollout for"
          enum: ["deployment" "daemonset" "statefulset"]
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
        delegate: (delegate-parameter)
      }
      required: ["subCommand" "resourceType" "name" "namespace"]
    }
  }
}

# 13. kube_exec - Execute command in pod
export def exec-in-pod-schema [] {
  {
    name: "kube_exec"
    description: "Execute a command in a Kubernetes pod or container and return the output"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["name" "command"]
    }
  }
}

# 14. kube_port_forward - Forward local port to pod/service
export def port-forward-schema [] {
  {
    name: "kube_port_forward"
    description: "Forward a local port to a port on a Kubernetes resource"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["resourceType" "resourceName" "localPort" "targetPort"]
    }
  }
}

# 15. kube_port_forward_stop - Stop port forwarding
export def kube-port-forward-stop-schema [] {
  {
    name: "kube_port_forward_stop"
    description: "Stop a port-forward process"
    input_schema: {
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
export def helm-install-schema [] {
  {
    name: "helm_install"
    description: "Install a Helm chart with support for both standard and template-based installation"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["name" "chart" "namespace"]
    }
  }
}

# 17. upgrade_helm_chart - Upgrade Helm release
export def helm-upgrade-schema [] {
  {
    name: "helm_upgrade"
    description: "Upgrade an existing Helm chart release"
    input_schema: {
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
        delegate: (delegate-parameter)
      }
      required: ["name" "chart" "namespace"]
    }
  }
}

# Delete Kubernetes resources
export def kubectl-delete-schema [] {
  {
    name: "kube_delete"
    description: "Delete Kubernetes resources by resource type, name, labels, or from a manifest file"
    input_schema: {
      type: "object"
      properties: {
        resourceType: {
          type: "string"
          description: "Type of resource to delete (e.g., pods, deployments, services, etc.)"
        }
        name: {
          type: "string"
          description: "Name of the resource to delete"
        }
        namespace: {
          type: "string"
          description: "Namespace containing the resource (defaults to 'default')"
        }
        labelSelector: {
          type: "string"
          description: "Delete resources matching this label selector (e.g. 'app=nginx')"
        }
        manifest: {
          type: "string"
          description: "YAML manifest defining resources to delete (optional)"
        }
        filename: {
          type: "string"
          description: "Path to a YAML file to delete resources from (optional)"
        }
        allNamespaces: {
          type: "boolean"
          description: "If true, delete resources across all namespaces"
          default: false
        }
        force: {
          type: "boolean"
          description: "If true, immediately remove resources from API and bypass graceful deletion"
          default: false
        }
        gracePeriodSeconds: {
          type: "number"
          description: "Period of time in seconds given to the resource to terminate gracefully"
        }
        context: {
          type: "string"
          description: "Kubernetes context to use (optional - defaults to current context)"
        }
        delegate: (delegate-parameter)
      }
      required: ["resourceType" "name" "namespace"]
    }
  }
}

# Uninstall a Helm chart release
export def helm-uninstall-schema [] {
  {
    name: "helm_uninstall"
    description: "Uninstall a Helm chart release"
    input_schema: {
      type: "object"
      properties: {
        name: {
          type: "string"
          description: "Name of the Helm release to uninstall"
        }
        namespace: {
          type: "string"
          description: "Namespace of the Helm release (defaults to 'default')"
        }
        context: {
          type: "string"
          description: "Kubernetes context to use (optional - defaults to current context)"
        }
        delegate: (delegate-parameter)
      }
      required: ["name" "namespace"]
    }
  }
}

# Cleanup all managed resources
export def cleanup-schema [] {
  {
    name: "kube_cleanup"
    description: "Cleanup all managed resources (port-forwards, etc.)"
    input_schema: {
      type: "object"
      properties: {}
    }
  }
}

# Manage Kubernetes nodes
export def node-management-schema [] {
  {
    name: "kube_node"
    description: "Manage Kubernetes nodes with cordon, drain, and uncordon operations"
    input_schema: {
      type: "object"
      properties: {
        operation: {
          type: "string"
          description: "Node operation to perform"
          enum: ["cordon" "drain" "uncordon"]
        }
        nodeName: {
          type: "string"
          description: "Name of the node to operate on (required for cordon, drain, uncordon)"
        }
        force: {
          type: "boolean"
          description: "Force the operation even if there are pods not managed by a ReplicationController, ReplicaSet, Job, DaemonSet or StatefulSet (for drain operation)"
          default: false
        }
        gracePeriod: {
          type: "number"
          description: "Period of time in seconds given to each pod to terminate gracefully (for drain operation). If set to -1, uses the kubectl default grace period."
          default: -1
        }
        deleteLocalData: {
          type: "boolean"
          description: "Delete local data even if emptyDir volumes are used (for drain operation)"
          default: false
        }
        ignoreDaemonsets: {
          type: "boolean"
          description: "Ignore DaemonSet-managed pods (for drain operation)"
          default: true
        }
        timeout: {
          type: "string"
          description: "The length of time to wait before giving up (for drain operation, e.g., '5m', '1h')"
          default: "0"
        }
        dryRun: {
          type: "boolean"
          description: "Show what would be done without actually doing it (for drain operation)"
          default: false
        }
        confirmDrain: {
          type: "boolean"
          description: "Explicit confirmation to drain the node (required for drain operation)"
          default: false
        }
        delegate: (delegate-parameter)
      }
      required: ["operation"]
    }
  }
}

# Schema Collection Functions

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
    (kube-port-forward-stop-schema)
    (helm-install-schema)
    (helm-upgrade-schema)
  ]
}

# Get Phase 2 destructive tool schemas
export def get-destructive-schemas [] {
  [
    (kubectl-delete-schema)
    (helm-uninstall-schema)
    (cleanup-schema)
    (node-management-schema)
  ]
}

# Get all tool schemas (Phase 1A + 1B + Phase 2)
export def get-all-schemas [] {
  (get-readonly-schemas) | append (get-non-destructive-schemas) | append (get-destructive-schemas)
}
