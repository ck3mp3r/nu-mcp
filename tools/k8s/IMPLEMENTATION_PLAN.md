# Kubernetes MCP Tool - Implementation Plan

## Overview
Build a Kubernetes MCP server for nu-mcp, mirroring the tool set from [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes) with Nushell-native implementation.

**Branch**: `feature/kubernetes-mcp-tool`

## Current Status

| Phase | Tools | Status | Date Completed |
|-------|-------|--------|----------------|
| **Phase 1A** | 7 read-only tools | ✅ **COMPLETE** | 2025-11-16 |
| **Phase 1B** | 10 non-destructive write tools | ✅ **COMPLETE** | 2025-11-16 |
| **Phase 2** | 5 destructive tools | ⏳ **TODO** | - |
| **Total** | **17/22 tools (77%)** | 🚀 **In Progress** | - |

### Files Created/Modified
- ✅ `utils.nu` - Core kubectl wrapper (350 lines)
- ✅ `formatters.nu` - Tool schemas for 17 tools (730 lines)
- ✅ `mod.nu` - MCP routing (119 lines)
- ✅ `resources.nu` - Resource operations (280 lines)
- ✅ `operations.nu` - Operational tools (560 lines)
- ✅ `helm.nu` - Helm operations (155 lines)
- ✅ `README.md` - User documentation (420 lines)
- ✅ `IMPLEMENTATION_PLAN.md` - This file
- ✅ `DEVELOPMENT_PROCESS.md` - Development guide (588 lines)

**Total Lines of Code**: ~2,600 lines

---

## Safety Model

### Three-Tier Access Control

#### Default: Non-Destructive Mode (17 tools)
**No environment variables required** - this is the default behavior.

Allows:
- ✅ All read operations (get, describe, logs, etc.)
- ✅ Create/update operations (apply, create, scale, patch)
- ✅ Execution operations (exec, port-forward)
- ✅ Helm install/upgrade
- ❌ Delete operations (delete, uninstall, cleanup)

#### Opt-In: Read-Only Mode (7 tools)
```bash
MCP_READ_ONLY=true
```

Allows:
- ✅ Only read operations
- ❌ All write/execute operations

#### Opt-In: Full Access Mode (22 tools)
```bash
MCP_ALLOW_DESTRUCTIVE=true
```

Allows:
- ✅ All operations including delete

### Environment Variable Precedence
```nushell
# Priority order (first match wins):
1. MCP_READ_ONLY=true           → 7 tools (most restrictive)
2. MCP_ALLOW_DESTRUCTIVE=true   → 22 tools (least restrictive)  
3. (default)                    → 17 tools (non-destructive)
```

---

## Tool Inventory (22 Total)

### Phase 1A: Core Read Operations (7 tools)

| # | Tool | Description | Mode Support |
|---|------|-------------|--------------|
| 1 | `kubectl_get` | Get/list Kubernetes resources | All |
| 2 | `kubectl_describe` | Describe resource details | All |
| 3 | `kubectl_logs` | Get pod/container logs | All |
| 4 | `kubectl_context` | Manage kubeconfig contexts (list/get/use) | All |
| 5 | `explain_resource` | Explain Kubernetes resource types | All |
| 6 | `list_api_resources` | List available API resources | All |
| 7 | `ping` | Verify kubectl connectivity | All |

### Phase 1B: Non-Destructive Operations (10 tools)

| # | Tool | Description | Mode Support |
|---|------|-------------|--------------|
| 8 | `kubectl_apply` | Apply YAML manifests | Non-Destructive, Full |
| 9 | `kubectl_create` | Create resources | Non-Destructive, Full |
| 10 | `kubectl_scale` | Scale replicas | Non-Destructive, Full |
| 11 | `kubectl_patch` | Update resource fields | Non-Destructive, Full |
| 12 | `kubectl_rollout` | Rollout operations (status/restart/undo) | Non-Destructive, Full |
| 13 | `port_forward` | Port forward to pod/service | Non-Destructive, Full |
| 14 | `stop_port_forward` | Stop port forwarding | Non-Destructive, Full |
| 15 | `exec_in_pod` | Execute command in pod | Non-Destructive, Full |
| 16 | `install_helm_chart` | Install Helm chart | Non-Destructive, Full |
| 17 | `upgrade_helm_chart` | Upgrade Helm release | Non-Destructive, Full |

### Phase 2: Destructive Operations (5 tools)

| # | Tool | Description | Mode Support |
|---|------|-------------|--------------|
| 18 | `kubectl_delete` | Delete resources | Full only |
| 19 | `uninstall_helm_chart` | Uninstall Helm release | Full only |
| 20 | `cleanup_pods` | Cleanup failed/evicted pods | Full only |
| 21 | `kubectl_generic` | Generic kubectl command | Full only |
| 22 | `node_management` | Cordon/drain/uncordon nodes | Full only |

---

## File Structure

```
tools/kubernetes/
├── mod.nu              # MCP interface & tool routing (~200 lines)
├── formatters.nu       # Tool schemas & definitions (~500 lines)
├── utils.nu            # kubectl CLI wrapper & helpers (~150 lines)
├── resources.nu        # Resource operations (get, describe, apply, delete)
├── operations.nu       # Operations (scale, logs, exec, port-forward, rollout)
├── helm.nu             # Helm operations (install, upgrade, uninstall)
├── advanced.nu         # Advanced operations (cleanup, node mgmt, generic)
├── README.md           # User documentation
├── IMPLEMENTATION_PLAN.md  # This file
└── TESTING.md          # Testing guide
```

---

## Configuration

### Environment Variables

```bash
# kubectl Configuration
KUBECONFIG=/path/to/kubeconfig    # Optional - defaults to ~/.kube/config
KUBE_CONTEXT=my-cluster           # Optional - override context
KUBE_NAMESPACE=default            # Optional - default namespace

# Safety Configuration
MCP_READ_ONLY=true                # Opt-in: Read-only mode (7 tools)
MCP_ALLOW_DESTRUCTIVE=true        # Opt-in: Full access mode (22 tools)
# (no flags)                      # Default: Non-destructive mode (17 tools)
```

### MCP Client Configuration

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "nu-mcp",
      "args": ["--tools-dir", "/path/to/nu-mcp/tools/kubernetes"],
      "env": {
        "KUBECONFIG": "/home/user/.kube/config",
        "KUBE_CONTEXT": "production",
        "KUBE_NAMESPACE": "default"
      }
    }
  }
}
```

#### Read-Only Configuration (Opt-In)
```json
{
  "env": {
    "MCP_READ_ONLY": "true"
  }
}
```

#### Full Access Configuration (Opt-In for Dev/Test)
```json
{
  "env": {
    "MCP_ALLOW_DESTRUCTIVE": "true"
  }
}
```

---

## Implementation Details

### Core Functions (utils.nu)

```nushell
# Main kubectl wrapper
export def run-kubectl [
    args: list<string>,
    --stdin: string = "",
    --namespace: string = "",
    --context: string = "",
    --output: string = "json"
] -> any {
    # Build kubectl command with proper flags
    # Handle context/namespace overrides
    # Parse output (JSON/YAML/text)
    # Error handling with clear messages
    # Return structured data
}

# Validation functions
export def check-kubectl [] -> bool
export def validate-resource-type [type: string] -> bool
export def get-current-context [] -> string

# Safety checking
export def is-tool-allowed [tool_name: string] -> bool {
    let mode = get-safety-mode
    match $mode {
        "readonly" => $tool_name in $readonly_tools,
        "non-destructive" => $tool_name not-in $destructive_tools,
        "full" => true
    }
}

export def get-safety-mode [] -> string {
    if ($env.MCP_READ_ONLY? | default "false") == "true" {
        "readonly"
    } else if ($env.MCP_ALLOW_DESTRUCTIVE? | default "false") == "true" {
        "full"
    } else {
        "non-destructive"  # Default
    }
}
```

### Tool Schema Pattern (formatters.nu)

```nushell
export def kubectl-get-schema [] -> record {
    {
        name: "kubectl_get"
        description: "Get or list Kubernetes resources by type, name, and namespace"
        inputSchema: {
            type: "object"
            properties: {
                resourceType: {
                    type: "string"
                    description: "Resource type (e.g., pods, deployments, services)"
                }
                name: {
                    type: "string"
                    description: "Resource name (optional - lists all if omitted)"
                }
                namespace: {
                    type: "string"
                    description: "Namespace (optional - defaults to KUBE_NAMESPACE or 'default')"
                }
                allNamespaces: {
                    type: "boolean"
                    description: "List resources across all namespaces"
                    default: false
                }
                output: {
                    type: "string"
                    enum: ["json", "yaml", "wide", "name"]
                    default: "json"
                }
                labelSelector: {
                    type: "string"
                    description: "Filter by labels (e.g., 'app=nginx')"
                }
                fieldSelector: {
                    type: "string"
                    description: "Filter by fields (e.g., 'status.phase=Running')"
                }
            }
            required: ["resourceType"]
        }
    }
}
```

---

## Development Phases

### Phase 1A: Core Infrastructure & Read Tools ✅ COMPLETE

**Deliverables**:
- [x] File structure created
- [x] `utils.nu` - kubectl wrapper & safety checking
- [x] `formatters.nu` - Tool schemas (7 read-only tools)
- [x] `mod.nu` - MCP routing for 7 tools
- [x] `resources.nu` - Implement get, describe
- [x] `operations.nu` - Implement logs, context, explain, list, ping
- [x] README.md - Basic documentation
- [x] Testing with local cluster (kind)
- [x] Nushell syntax fixes applied
- [x] LLM-friendly descriptions aligned with reference

**Tools**: 7 (kubectl_get, kubectl_describe, kubectl_logs, kubectl_context, explain_resource, list_api_resources, ping)

**Status**: All 7 tools implemented and tested with kind cluster ✅

### Phase 1B: Non-Destructive Write Operations ✅ COMPLETE

**Deliverables**:
- [x] Extend `formatters.nu` - Add 10 non-destructive tool schemas
- [x] Extend `resources.nu` - Implement apply, create, patch
- [x] Extend `operations.nu` - Implement scale, rollout, exec, port-forward
- [x] `helm.nu` - Implement install, upgrade (new file created)
- [x] Safety mode enforcement in `mod.nu`
- [x] Port forward simplified implementation (noted for future enhancement)
- [x] Integration testing with kind cluster

**Tools**: 17 total (7 read + 10 write)

**Status**: All 10 Phase 1B tools implemented and tested ✅
- kubectl_apply, kubectl_create, kubectl_patch (resources.nu)
- kubectl_scale, kubectl_rollout, exec_in_pod, port_forward, stop_port_forward (operations.nu)
- install_helm_chart, upgrade_helm_chart (helm.nu)

### Phase 2: Destructive Operations (Day 5)

**Deliverables**:
- [ ] Extend `formatters.nu` - Add 5 destructive tool schemas
- [ ] `advanced.nu` - Implement cleanup_pods, node_management, kubectl_generic
- [ ] Extend `resources.nu` - Implement delete
- [ ] Extend `helm.nu` - Implement uninstall
- [ ] Full safety mode testing
- [ ] Documentation completion

**Tools**: 22 total (17 + 5 destructive)

---

## Testing Strategy

### Prerequisites
```bash
# Install kubectl
which kubectl

# Verify cluster access
kubectl cluster-info

# List contexts
kubectl config get-contexts

# Set up test cluster (choose one)
minikube start
# OR
kind create cluster --name test-mcp
# OR
k3d cluster create test-mcp
```

### Test Cases

#### 1. Safety Mode Tests
```bash
# Test default (non-destructive)
source mod.nu
main list-tools | length  # Should be 17

# Test read-only mode
MCP_READ_ONLY=true source mod.nu
main list-tools | length  # Should be 7

# Test full access
MCP_ALLOW_DESTRUCTIVE=true source mod.nu
main list-tools | length  # Should be 22
```

#### 2. Tool Function Tests
```bash
# Test kubectl_get
main call-tool kubectl_get {resourceType: "pods", namespace: "default"}

# Test kubectl_apply
main call-tool kubectl_apply {
    manifest: "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: test-cm"
}

# Test safety blocks
main call-tool kubectl_delete {resourceType: "pod", name: "test"}
# Should error in non-destructive mode
```

#### 3. Integration Tests
- Deploy test application
- Scale deployment
- Get logs
- Port forward
- Execute command in pod
- Clean up

---

## Success Criteria

### Phase 1A Complete ✅
- ✅ 7 read-only tools working
- ✅ kubectl wrapper handles JSON/YAML parsing
- ✅ Safety mode correctly filters tools
- ✅ Error messages are clear
- ✅ Tested with kind cluster
- ✅ All Nushell syntax issues resolved
- ✅ Descriptions aligned with reference implementation

**Date Completed**: 2025-11-16

### Phase 1B Complete ✅
- ✅ 17 non-destructive tools working
- ✅ Apply/create operations succeed (tested with configmap)
- ✅ kubectl_patch updates resources successfully
- ✅ kubectl_scale tested with coredns deployment
- ✅ kubectl_rollout status checked
- ✅ exec_in_pod implemented (simplified for minimal containers)
- ✅ Port forwarding implemented (simplified, noted for enhancement)
- ✅ Helm install/upgrade implemented
- ✅ Safety mode blocks write operations in read-only mode
- ✅ All tools tested with kind cluster

**Date Completed**: 2025-11-16

### Phase 2 Complete
- [ ] All 22 tools implemented
- [ ] Delete operations work in full mode
- [ ] Delete operations blocked in non-destructive mode
- [ ] Documentation complete
- [ ] Nix package builds

**Status**: Not started

---

## Dependencies

### Required
- `kubectl` CLI (user must install)
- Valid kubeconfig file
- Kubernetes cluster access

### Optional
- `helm` CLI (for Helm operations)
- Local cluster (minikube/kind/k3d) for testing

---

## Nix Integration

Add to `nix/packages.nix`:

```nix
kubernetes-mcp-tools = pkgs.stdenv.mkDerivation {
  name = "kubernetes-mcp-tools";
  src = ../tools/kubernetes;
  
  installPhase = ''
    mkdir -p $out
    cp -r * $out/
  '';
  
  meta = {
    description = "Kubernetes MCP tools for nu-mcp";
    platforms = pkgs.lib.platforms.all;
  };
};
```

Update `flake.nix` packages output to include `kubernetes-mcp-tools`.

---

## Timeline Estimate

- **Phase 1A** (Core + Read): 12-16 hours
- **Phase 1B** (Non-Destructive): 12-16 hours
- **Phase 2** (Destructive): 6-8 hours
- **Total**: 30-40 hours for complete implementation

---

## Notes

- Default behavior matches safety-first principle (non-destructive)
- Tool names exactly match reference implementation for compatibility
- Nushell provides better structured data handling than TypeScript
- Safety model is simpler but equally effective (env var precedence)
- Port forwarding requires background process management
- Secret masking should be implemented for `kubectl get secrets`

---

## References

- [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes) - Reference implementation
- [ArgoCD MCP Tool](../argocd/README.md) - Sister implementation pattern
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/) - kubectl reference
