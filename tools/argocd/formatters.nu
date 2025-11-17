# Tool schema definitions for ArgoCD MCP server

# Get list of read-only tool names (tools safe for MCP_READ_ONLY mode)
export def get-readonly-tools [] {
  [
    "list-applications"
    "get-application"
    "get-application-resource-tree"
    "get-application-managed-resources"
    "get-application-workload-logs"
    "get-application-events"
    "get-resource-events"
    "get-resources"
    "get-resource-actions"
  ]
}

# Get list of write tool names (disabled in MCP_READ_ONLY mode)
export def get-write-tools [] {
  [
    "create-application"
    "update-application"
    "delete-application"
    "sync-application"
    "run-resource-action"
  ]
}

# Check if a tool is allowed based on read-only mode
export def is-tool-allowed [tool_name: string read_only: bool] {
  if $read_only {
    $tool_name in (get-readonly-tools)
  } else {
    true # All tools allowed when not in read-only mode
  }
}

# Get all tool definitions
export def get-tool-definitions [] {
  [
    {
      name: "list-applications"
      description: "list_applications returns list of applications"
      input_schema: {
        type: "object"
        properties: {
          search: {
            type: "string"
            description: "Search applications by name. This is a partial match on the application name and does not support glob patterns (e.g. '*'). Optional."
          }
          limit: {
            type: "integer"
            description: "Maximum number of applications to return. Use this to reduce token usage when there are many applications. Optional."
          }
          offset: {
            type: "integer"
            description: "Number of applications to skip before returning results. Use with limit for pagination. Optional."
          }
        }
        additionalProperties: false
      }
    }
    {
      name: "get-application"
      description: "get_application returns application by application name. Optionally specify the application namespace to get applications from non-default namespaces."
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          appNamespace: {
            type: "string"
            description: "Namespace of the application (optional)"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "create-application"
      description: "create_application creates a new ArgoCD application in the specified namespace. The application.metadata.namespace field determines where the Application resource will be created (e.g., 'argocd', 'argocd-apps', or any custom namespace)."
      input_schema: {
        type: "object"
        properties: {
          application: {
            type: "object"
            description: "Application specification (ArgoCD Application manifest)"
          }
        }
        required: ["application"]
      }
    }
    {
      name: "update-application"
      description: "update_application updates application"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application to update"
          }
          application: {
            type: "object"
            description: "Updated application specification"
          }
        }
        required: ["applicationName" "application"]
      }
    }
    {
      name: "delete-application"
      description: "delete_application deletes application. Specify applicationNamespace if the application is in a non-default namespace to avoid permission errors."
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application to delete"
          }
          appNamespace: {
            type: "string"
            description: "The namespace where the application is located. Required if application is not in the default namespace."
          }
          cascade: {
            type: "boolean"
            description: "Whether to cascade the deletion to child resources"
          }
          propagationPolicy: {
            type: "string"
            description: "Deletion propagation policy (e.g., 'Foreground', 'Background', 'Orphan')"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "sync-application"
      description: "sync_application syncs application. Specify applicationNamespace if the application is in a non-default namespace to avoid permission errors."
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application to sync"
          }
          appNamespace: {
            type: "string"
            description: "The namespace where the application is located. Required if application is not in the default namespace."
          }
          dryRun: {
            type: "boolean"
            description: "Perform a dry run sync without applying changes"
          }
          prune: {
            type: "boolean"
            description: "Remove resources that are no longer defined in the source"
          }
          revision: {
            type: "string"
            description: "Sync to a specific revision instead of the latest"
          }
          syncOptions: {
            type: "array"
            items: {type: "string"}
            description: "Additional sync options (e.g., ['CreateNamespace=true', 'PrunePropagationPolicy=foreground'])"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get-application-resource-tree"
      description: "get_application_resource_tree returns resource tree for application by application name"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get-application-managed-resources"
      description: "get_application_managed_resources returns managed resources for application by application name with optional filtering. Use filters to avoid token limits with large applications. Examples: kind='ConfigMap' for config maps only, namespace='production' for specific namespace, or combine multiple filters."
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          kind: {
            type: "string"
            description: "Filter by Kubernetes resource kind (e.g., 'ConfigMap', 'Secret', 'Deployment')"
          }
          namespace: {
            type: "string"
            description: "Filter by Kubernetes namespace"
          }
          name: {
            type: "string"
            description: "Filter by resource name"
          }
          version: {
            type: "string"
            description: "Filter by resource API version"
          }
          group: {
            type: "string"
            description: "Filter by API group"
          }
          appNamespace: {
            type: "string"
            description: "Filter by Argo CD application namespace"
          }
          project: {
            type: "string"
            description: "Filter by Argo CD project"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get-application-workload-logs"
      description: "get_application_workload_logs returns logs for application workload (Deployment, StatefulSet, Pod, etc.) by application name and resource ref and optionally container name"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          applicationNamespace: {
            type: "string"
            description: "Application namespace"
          }
          namespace: {
            type: "string"
            description: "Resource namespace"
          }
          resourceName: {
            type: "string"
            description: "Resource name"
          }
          group: {
            type: "string"
            description: "Resource group"
          }
          kind: {
            type: "string"
            description: "Resource kind (Pod, Deployment, etc.)"
          }
          version: {
            type: "string"
            description: "Resource version"
          }
          container: {
            type: "string"
            description: "Container name within the resource"
          }
          tailLines: {
            type: "integer"
            description: "Number of lines to tail from logs"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get-application-events"
      description: "get_application_events returns events for application by application name"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get-resource-events"
      description: "get_resource_events returns events for a resource that is managed by an application"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          applicationNamespace: {
            type: "string"
            description: "Application namespace"
          }
          resourceNamespace: {
            type: "string"
            description: "Resource namespace"
          }
          resourceName: {
            type: "string"
            description: "Resource name"
          }
          resourceUID: {
            type: "string"
            description: "Resource UID"
          }
        }
        required: ["applicationName" "applicationNamespace" "resourceUID" "resourceNamespace" "resourceName"]
      }
    }
    {
      name: "get-resources"
      description: "get_resources returns manifests for resources specified by resourceRefs. If resourceRefs is empty or not provided, fetches all resources managed by the application."
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          applicationNamespace: {
            type: "string"
            description: "Application namespace"
          }
          resourceRefs: {
            type: "array"
            items: {
              type: "object"
              properties: {
                uid: {type: "string"}
                version: {type: "string"}
                group: {type: "string"}
                kind: {type: "string"}
                name: {type: "string"}
                namespace: {type: "string"}
              }
            }
            description: "List of resource references (optional)"
          }
        }
        required: ["applicationName" "applicationNamespace"]
      }
    }
    {
      name: "get-resource-actions"
      description: "get_resource_actions returns actions for a resource that is managed by an application"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          applicationNamespace: {
            type: "string"
            description: "Application namespace"
          }
          namespace: {
            type: "string"
            description: "Resource namespace"
          }
          kind: {
            type: "string"
            description: "Resource kind"
          }
          resourceName: {
            type: "string"
            description: "Resource name"
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "run-resource-action"
      description: "run_resource_action runs an action on a resource"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          action: {
            type: "string"
            description: "Action to run"
          }
          applicationNamespace: {
            type: "string"
            description: "Application namespace"
          }
          namespace: {
            type: "string"
            description: "Resource namespace"
          }
          kind: {
            type: "string"
            description: "Resource kind"
          }
          resourceName: {
            type: "string"
            description: "Resource name"
          }
        }
        required: ["applicationName" "action"]
      }
    }
  ]
}
