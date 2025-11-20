# Tool schema definitions for ArgoCD MCP server

# Get list of read-only tool names (tools safe for MCP_READ_ONLY mode)
export def get-readonly-tools [] {
  [
    "list_applications"
    "get_application"
    "get_application_resource_tree"
    "get_application_managed_resources"
    "get_application_workload_logs"
    "get_application_events"
    "get_resource_events"
    "get_resources"
    "get_resource_actions"
  ]
}

# Get list of write tool names (disabled in MCP_READ_ONLY mode)
export def get-write-tools [] {
  [
    "create_application"
    "update_application"
    "delete_application"
    "sync_application"
    "run_resource_action"
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
      name: "list_applications"
      description: "list_applications returns list of applications. Results are automatically summarized by default to reduce token usage - only essential fields like name, status, health, sync state, and source/destination info are returned. Set summarize=false to get full application objects."
      input_schema: {
        type: "object"
        properties: {
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
          search: {
            type: "string"
            description: "Search applications by name. This is a partial match on the application name and does not support glob patterns (e.g. '*'). Optional."
          }
          limit: {
            type: "integer"
            description: "Maximum number of applications to return. Use this to reduce token usage when there are many applications. Optional."
          }
          summarize: {
            type: "boolean"
            description: "Summarize results to reduce token usage by returning only essential fields (default: true). Set to false to get full application objects. Optional."
          }
        }
        additionalProperties: false
      }
    }
    {
      name: "get_application"
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
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "create_application"
      description: "create_application creates a new ArgoCD application in the specified namespace. The application.metadata.namespace field determines where the Application resource will be created (e.g., 'argocd', 'argocd-apps', or any custom namespace)."
      input_schema: {
        type: "object"
        properties: {
          application: {
            type: "object"
            description: "Application specification (ArgoCD Application manifest)"
          }
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["application"]
      }
    }
    {
      name: "update_application"
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
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName" "application"]
      }
    }
    {
      name: "delete_application"
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
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "sync_application"
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
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get_application_resource_tree"
      description: "get_application_resource_tree returns resource tree for application by application name"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get_application_managed_resources"
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
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080'). When provided alone, assumes user logged in via 'argocd login'. When provided with namespace, auto-discovers credentials and logs in automatically."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get_application_workload_logs"
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
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080'). When provided alone, assumes user logged in via 'argocd login'. When provided with namespace, auto-discovers credentials and logs in automatically."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get_application_events"
      description: "get_application_events returns events for application by application name"
      input_schema: {
        type: "object"
        properties: {
          applicationName: {
            type: "string"
            description: "Name of the application"
          }
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "get_resource_events"
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
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName" "applicationNamespace" "resourceUID" "resourceNamespace" "resourceName"]
      }
    }
    {
      name: "get_resources"
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
          namespace: {
            type: "string"
            description: "Kubernetes namespace where ArgoCD is installed. REQUIRED with server parameter to enable automatic credential discovery and login. Use 'argocd' for standard installations."
          }
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080' or 'https://argocd.example.com'). MUST be provided WITH namespace parameter to enable automatic credential discovery and login. Without namespace, assumes pre-existing 'argocd login' session. Note: localhost URLs automatically use --insecure and --grpc-web flags. For non-localhost URLs with self-signed certificates, set MCP_INSECURE_TLS=true environment variable."
          }
        }
        required: ["applicationName" "applicationNamespace"]
      }
    }
    {
      name: "get_resource_actions"
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
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080'). When provided alone, assumes user logged in via 'argocd login'. When provided with namespace, auto-discovers credentials and logs in automatically."
          }
        }
        required: ["applicationName"]
      }
    }
    {
      name: "run_resource_action"
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
          server: {
            type: "string"
            description: "ArgoCD server URL (e.g., 'https://localhost:8080'). When provided alone, assumes user logged in via 'argocd login'. When provided with namespace, auto-discovers credentials and logs in automatically."
          }
        }
        required: ["applicationName" "action"]
      }
    }
  ]
}
