# K8s MCP Tool - Development Process Documentation

This document captures the proven process for implementing Kubernetes MCP tools in Nushell, based on the successful Phase 1A implementation.

## Reference Implementation

**Source**: [Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes) (1.2k⭐)  
**Location**: `/tmp/mcp-server-kubernetes/`  
**Language**: TypeScript  
**Our Implementation**: Nushell

## Implementation Process (Proven Pattern)

### Step 1: Research Reference Implementation

**Goal**: Understand exact tool names, descriptions, and parameters from the reference.

```bash
# Clone reference if needed
git clone --depth 1 https://github.com/Flux159/mcp-server-kubernetes /tmp/mcp-server-kubernetes

# Key files to read:
/tmp/mcp-server-kubernetes/src/tools/kubectl-*.ts
/tmp/mcp-server-kubernetes/src/tools/helm-*.ts
/tmp/mcp-server-kubernetes/src/tools/exec*.ts
/tmp/mcp-server-kubernetes/src/tools/port*.ts
/tmp/mcp-server-kubernetes/src/tools/kubectl-operations.ts
```

**Extract for Each Tool**:
1. Exact tool name (e.g., `kubectl_get`)
2. Exact description (first line after `description:`)
3. All parameter names and descriptions
4. Required vs optional parameters
5. Default values
6. Enum values for choices

### Step 2: Create Infrastructure (One-Time Setup)

**Files Created** (Phase 1A):
- `utils.nu` - Core kubectl wrapper and helper functions
- `formatters.nu` - Tool schemas with MCP-compliant structure
- `mod.nu` - MCP routing and tool dispatch
- `resources.nu` - Resource operations
- `operations.nu` - Operational tools
- `README.md` - Documentation

**For New Phases** (1B, 2):
- May add `helm.nu` for Helm operations
- May add `advanced.nu` for destructive operations

### Step 3: Update formatters.nu with Tool Schemas

**Pattern**: Match reference implementation EXACTLY

```nushell
# Reference (TypeScript):
export const kubectlApplySchema = {
  name: "kubectl_apply",
  description: "Apply a configuration to a resource by file name or stdin",
  inputSchema: {
    type: "object",
    properties: {
      manifest: {
        type: "string",
        description: "YAML or JSON manifest content"
      },
      // ... more properties
    },
    required: ["manifest"]
  }
}

# Our Implementation (Nushell):
export def kubectl-apply-schema [] {
    {
        name: "kubectl_apply"
        description: "Apply a configuration to a resource by file name or stdin"
        inputSchema: {
            type: "object"
            properties: {
                manifest: {
                    type: "string"
                    description: "YAML or JSON manifest content"
                }
                # ... more properties
            }
            required: ["manifest"]
        }
    }
}
```

**Key Rules**:
1. Description MUST match reference exactly (concise for LLM efficiency)
2. Parameter descriptions should be concise, not over-explained
3. Use exact enum values from reference
4. Keep default values consistent
5. No type annotations in function signature

### Step 4: Implement Tool Functions

**File Organization**:
```
utils.nu       → Core utilities (kubectl wrapper, safety checks, formatting)
formatters.nu  → Tool schemas ONLY (MCP definitions)
resources.nu   → Resource CRUD (get, describe, apply, create, delete, patch)
operations.nu  → Operations (logs, context, scale, rollout, exec, port-forward)
helm.nu        → Helm operations (install, upgrade, uninstall)
advanced.nu    → Advanced/destructive (cleanup, node management, generic kubectl)
```

**Implementation Pattern**:

```nushell
# In resources.nu, operations.nu, helm.nu, or advanced.nu
export def kubectl-apply [
    params: record
] {
    # 1. Extract parameters with defaults
    let manifest = $params.manifest? | default ""
    let namespace = $params.namespace? | default ""
    let dry_run = $params.dryRun? | default false
    let context = $params.context? | default ""
    
    # 2. Validate required parameters
    if $manifest == "" {
        return (format-tool-response {
            error: "MissingParameter"
            message: "manifest parameter is required"
            isError: true
        } --error true)
    }
    
    # 3. Build kubectl arguments
    mut args = ["apply" "-f" "-"]  # - means stdin
    
    if $dry_run {
        $args = ($args | append "--dry-run=client")
    }
    
    # 4. Execute kubectl command
    let result = run-kubectl $args --stdin $manifest --namespace $namespace --context $context --output "json"
    
    # 5. Check for errors
    if ($result | describe | str contains "record") and ($result | get isError? | default false) {
        return (format-tool-response $result --error true)
    }
    
    # 6. Format response
    format-tool-response {
        operation: "apply"
        result: $result
    }
}
```

### Step 5: Update mod.nu Routing

```nushell
# In mod.nu, add to call_tool function
def call_tool [
    tool_name: string
    params: record
] {
    # ... existing tools ...
    
    match $tool_name {
        # ... existing cases ...
        
        # NEW TOOLS
        "kubectl_apply" => { kubectl-apply $params }
        "kubectl_create" => { kubectl-create $params }
        # ... more new tools ...
        
        _ => {
            # Unknown tool error
        }
    }
}
```

### Step 6: Critical Nushell Syntax Rules

#### ❌ NEVER Use Type Annotations

```nushell
# ❌ WRONG
export def my-func [] -> record { }
export def another-func [arg: string] -> bool { }

# ✅ CORRECT
export def my-func [] { }
export def another-func [arg: string] { }
```

#### ❌ NEVER Type Boolean Flags

```nushell
# ❌ WRONG
export def my-func [--flag: bool = false] { }

# ✅ CORRECT
export def my-func [--flag = false] { }
```

#### ❌ NEVER Use Boolean Flags Without Value

```nushell
# ❌ WRONG
format-tool-response $data --error

# ✅ CORRECT
format-tool-response $data --error true
```

#### ❌ NEVER Capture Mutable Variables in Closures

```nushell
# ❌ WRONG
mut cmd_args = ["kubectl"]
try {
    let cmd_str = ($cmd_args | str join " ")  # Error: capture of mutable
}

# ✅ CORRECT
mut cmd_args = ["kubectl"]
let cmd_str = ($cmd_args | str join " ")  # Extract before try
try {
    # Use $cmd_str here
}
```

#### ✅ Kubectl Command Flag Ordering

```nushell
# ✅ CORRECT ORDER
# kubectl [global-flags] subcommand [subcommand-flags]

mut cmd_args = ["kubectl"]

# 1. Global flags first (--context)
if $context != "" {
    $cmd_args = ($cmd_args | append ["--context" $context])
}

# 2. Subcommand next (get, apply, delete)
$cmd_args = ($cmd_args | append $args)

# 3. Subcommand-specific flags last (--namespace, --all-namespaces, --output)
if $namespace != "" {
    $cmd_args = ($cmd_args | append ["--namespace" $namespace])
}
```

### Step 7: Testing Process

#### A. Test Tool Availability

```bash
cd /Users/christian/Projects/ck3mp3r/nu-mcp/tools/k8s

# Should show correct number of tools based on mode
nu -c 'source mod.nu; main list-tools | get tools | length'
# Default: 17 (Phase 1A: 7, Phase 1B: +10)

# Read-only mode
MCP_READ_ONLY=true nu -c 'source mod.nu; main list-tools | get tools | length'
# Should show: 7

# Full access mode
MCP_ALLOW_DESTRUCTIVE=true nu -c 'source mod.nu; main list-tools | get tools | length'
# Should show: 22 (when Phase 2 complete)
```

#### B. Test Individual Tool

```bash
# Ping test (always available)
nu -c 'source mod.nu; main call-tool ping {} | get content.0.text | from json'

# Test with parameters
nu -c 'source mod.nu; main call-tool kubectl_get {resourceType: "pods"} | get content.0.text | from json'

# Test with namespace
nu -c 'source mod.nu; main call-tool kubectl_get {resourceType: "pods", namespace: "kube-system"} | get content.0.text | from json'
```

#### C. Test with Real Cluster

```bash
# Verify cluster access first
kubectl cluster-info
kubectl get nodes

# Test read operations
nu -c 'source mod.nu; main call-tool kubectl_get {resourceType: "nodes"}'
nu -c 'source mod.nu; main call-tool kubectl_describe {resourceType: "node", name: "NODE-NAME"}'

# Test write operations (if implementing Phase 1B)
nu -c 'source mod.nu; main call-tool kubectl_apply {manifest: "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: test-cm"}'
```

#### D. Test Safety Mode Filtering

```bash
# Test that destructive operations are blocked by default
nu -c 'source mod.nu; main call-tool kubectl_delete {resourceType: "pod", name: "test"}'
# Should return PermissionDenied error

# Test that they work with full access
MCP_ALLOW_DESTRUCTIVE=true nu -c 'source mod.nu; main call-tool kubectl_delete {resourceType: "pod", name: "test"}'
# Should attempt delete (or fail if pod doesn't exist)
```

### Step 8: Commit Process

**Commit Message Pattern**:

```
feat|fix|docs: <concise summary>

<detailed description>

Changes:
- Tool 1: description
- Tool 2: description
- ...

Testing:
✅ All tools tested with kind cluster
✅ Safety mode filtering verified
✅ Error handling validated
```

**Example**:

```
feat: implement Phase 1B - k8s non-destructive write operations (10 tools)

Added 10 non-destructive write tools following reference implementation:

Write Operations (resources.nu):
- kubectl_apply: Apply YAML manifests
- kubectl_create: Create resources
- kubectl_patch: Update resource fields

Operations (operations.nu):
- kubectl_scale: Scale replicas
- kubectl_rollout: Rollout management
- kubectl_exec: Execute in pods
- port_forward: Port forwarding
- stop_port_forward: Stop port forwarding

Helm Operations (helm.nu - new file):
- install_helm_chart: Install Helm charts
- upgrade_helm_chart: Upgrade releases

Testing:
✅ All 10 tools tested with kind cluster
✅ Safety mode shows 17 tools (7 + 10)
✅ Write operations blocked in read-only mode
✅ Port forwarding process management working
```

---

## File Structure Reference

```
tools/k8s/
├── mod.nu                      # MCP routing (main entry point)
├── formatters.nu               # Tool schemas (MCP definitions)
├── utils.nu                    # Core utilities (kubectl wrapper, safety)
├── resources.nu                # Resource CRUD operations
├── operations.nu               # Operational tools
├── helm.nu                     # Helm operations (Phase 1B+)
├── advanced.nu                 # Advanced/destructive (Phase 2)
├── README.md                   # User documentation
├── IMPLEMENTATION_PLAN.md      # Roadmap (22 tools, 3 phases)
└── DEVELOPMENT_PROCESS.md      # This file
```

---

## Common Patterns

### Error Handling Pattern

```nushell
# Check for missing required parameter
if $param == "" {
    return (format-tool-response {
        error: "MissingParameter"
        message: "param is required"
        isError: true
    } --error true)
}

# Check for kubectl command errors
if ($result | describe | str contains "record") and ($result | get isError? | default false) {
    return (format-tool-response $result --error true)
}
```

### Parameter Extraction Pattern

```nushell
# Required parameter
let name = $params.name

# Optional with default
let namespace = $params.namespace? | default ""
let dry_run = $params.dryRun? | default false
let output = $params.output? | default "json"

# Optional from environment
let context = if ($params.context? | default "") != "" {
    $params.context
} else {
    $env.KUBE_CONTEXT? | default ""
}
```

### kubectl Wrapper Usage Pattern

```nushell
# Simple get
let result = run-kubectl ["get" "pods"] --namespace $namespace

# With stdin (for apply, create)
let result = run-kubectl ["apply" "-f" "-"] --stdin $manifest --namespace $namespace

# With output format override
let result = run-kubectl ["describe" "pod" $name] --namespace $namespace --output "text"

# With all-namespaces flag
let result = run-kubectl ["get" "pods"] --all-namespaces true
```

---

## Safety Model Implementation

### Tool Categories

```nushell
# In utils.nu

# Read-only tools (7) - Always available
export def readonly-tools [] {
    [
        "kubectl_get"
        "kubectl_describe"
        "kubectl_logs"
        "kubectl_context"
        "explain_resource"
        "list_api_resources"
        "ping"
    ]
}

# Destructive tools (5) - Require MCP_ALLOW_DESTRUCTIVE=true
export def destructive-tools [] {
    [
        "kubectl_delete"
        "uninstall_helm_chart"
        "cleanup_pods"
        "kubectl_generic"
        "node_management"
    ]
}

# Non-destructive write tools (10) - Available by default
# All tools NOT in readonly-tools or destructive-tools
```

### Safety Check Pattern

```nushell
# In mod.nu, before executing tool
if not (is-tool-allowed $tool_name) {
    return (permission-denied-error $tool_name)
}
```

---

## Quick Reference Checklist

**Before Starting New Phase**:
- [ ] Read reference implementation files
- [ ] Document tool names and descriptions
- [ ] Plan file organization (which .nu file)

**During Implementation**:
- [ ] Update formatters.nu (exact descriptions from reference)
- [ ] Implement tool functions (appropriate .nu file)
- [ ] Update mod.nu routing
- [ ] No type annotations anywhere
- [ ] Boolean flags have explicit values
- [ ] Extract variables before try blocks

**Testing**:
- [ ] Test each tool individually
- [ ] Verify with kind cluster
- [ ] Test safety mode filtering
- [ ] Verify error messages are clear

**Before Commit**:
- [ ] All descriptions match reference exactly
- [ ] No Nushell syntax errors
- [ ] All tests passing
- [ ] README.md updated if needed

---

## Troubleshooting Guide

### "Parse mismatch" errors
- Remove all type annotations (`-> type`, `: bool`)
- Check for `->` anywhere in function signatures

### "Missing flag argument" errors
- Change `--flag` to `--flag true` for boolean flags

### "Capture of mutable variable" errors
- Extract variable before try block
- Avoid using mut variables in closures

### "Flags cannot be placed before plugin name" errors
- Check kubectl command flag ordering
- Global flags (--context) before subcommand
- Subcommand flags (--namespace) after subcommand

### Tool not showing in list-tools
- Check if tool is in formatters.nu schemas
- Verify get-all-schemas includes the tool
- Check safety mode allows the tool

### Tool shows but fails when called
- Check mod.nu routing matches tool name
- Verify function is exported from .nu file
- Check for parameter name mismatches

---

## Reference Implementation Mapping

### Phase 1A (7 tools) - ✅ Complete
| Our Tool | Reference File | Our File |
|----------|----------------|----------|
| kubectl_get | kubectl-get.ts | resources.nu |
| kubectl_describe | kubectl-describe.ts | resources.nu |
| kubectl_logs | kubectl-logs.ts | operations.nu |
| kubectl_context | kubectl-context.ts | operations.nu |
| explain_resource | kubectl-operations.ts | operations.nu |
| list_api_resources | kubectl-operations.ts | operations.nu |
| ping | ping.ts | operations.nu |

### Phase 1B (10 tools) - ⏳ TODO
| Our Tool | Reference File | Our File |
|----------|----------------|----------|
| kubectl_apply | kubectl-apply.ts | resources.nu |
| kubectl_create | kubectl-create.ts | resources.nu |
| kubectl_patch | kubectl-patch.ts | resources.nu |
| kubectl_scale | kubectl-scale.ts | operations.nu |
| kubectl_rollout | kubectl-rollout.ts | operations.nu |
| exec_in_pod | exec_in_pod.ts | operations.nu |
| port_forward | port_forward.ts | operations.nu |
| stop_port_forward | port_forward.ts | operations.nu |
| install_helm_chart | helm-operations.ts | helm.nu (new) |
| upgrade_helm_chart | helm-operations.ts | helm.nu (new) |

### Phase 2 (5 tools) - ⏳ TODO
| Our Tool | Reference File | Our File |
|----------|----------------|----------|
| kubectl_delete | kubectl-delete.ts | resources.nu |
| uninstall_helm_chart | helm-operations.ts | helm.nu |
| cleanup_pods | TBD | advanced.nu (new) |
| kubectl_generic | kubectl-generic.ts | advanced.nu (new) |
| node_management | node-management.ts | advanced.nu (new) |

---

## End of Development Process Documentation

This document should be referenced whenever implementing new tools or when context is lost after compacting.
