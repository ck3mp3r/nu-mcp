# nu-mcp: Model Context Protocol (MCP) Server for Nushell

This project exposes Nushell as an MCP server using the official Rust SDK (`rmcp`).

## Features
- Exposes a tool to run arbitrary Nushell commands via MCP
- **Configurable timeout support** - Set global defaults via `MCP_NU_MCP_TIMEOUT` or per-call with `timeout_seconds` parameter
- Extensible tool system via Nushell scripts in modular directories
- Uses the official Model Context Protocol Rust SDK
- Security sandbox with intelligent path validation and caching
- Catalog of useful MCP tools for weather, finance, and more

## Quick Start

### Core Mode (Default)
```bash
nu-mcp
```
Provides the `run_nushell` tool for executing arbitrary Nushell commands.

### Extension Mode  
```bash
nu-mcp --tools-dir=./tools
```
Load tools from the included catalog or your custom tool modules. Each tool is a directory with a `mod.nu` entry file.

### Hybrid Mode
```bash
nu-mcp --tools-dir=./tools --enable-run-nushell
```
Combine both core command execution and extension tools.

## Available Tools

The `tools/` directory contains a growing catalog of useful MCP tools:

- **c5t** (`tools/c5t/`) - **[EXPERIMENTAL]** Context/memory management across LLM sessions with git-backed sync
- **Kubernetes** (`tools/k8s/`) - Complete kubectl/Helm interface with 22 tools and three-tier safety model
- **ArgoCD** (`tools/argocd/`) - ArgoCD application and resource management via HTTP API
- **Weather** (`tools/weather/`) - Current weather and forecasts using Open-Meteo API
- **Finance** (`tools/finance/`) - Stock prices and financial data using Yahoo Finance API
- **Tmux** (`tools/tmux/`) - Tmux session and pane management with intelligent command execution
- **Context7** (`tools/c67/`) - Up-to-date library documentation and code examples from Context7

## Configuration

### Command Line Options
- `--tools-dir=PATH` - Directory containing tool modules
- `--enable-run-nushell` - Enable generic command execution alongside tools  
- `--add-path=PATH` - Add additional accessible paths (current directory always included)

### Environment Variables
- `MCP_NU_MCP_TIMEOUT` - Default timeout in seconds for tool execution (default: 60)

### Example MCP Configuration
```yaml
nu-mcp:
  command: "nu-mcp"
  args: ["--tools-dir=./tools", "--add-path=/tmp", "--add-path=/nix/store"]
  env:
    MCP_NU_MCP_TIMEOUT: "120"  # 2 minute timeout
```
Note: Current working directory is always accessible. Use `--add-path` to grant access to additional paths.

### Path Validation

The security sandbox intelligently handles path-like strings that aren't filesystem paths:

```bash
# API endpoints work without escaping sandbox
kubectl get --raw /metrics | from json
gh api /repos/owner/repo/contents/file.yml

# Path-like arguments in commands work correctly
echo "API endpoint: /api/v1/pods"
```

The sandbox uses a two-tier system (safe patterns + runtime caching) to eliminate false positives while maintaining security.

For detailed configuration options and tool development, see the [documentation](docs/).

## Safety and Destructive Operations

**IMPORTANT**: All destructive MCP tools require explicit user confirmation before execution.

Destructive tools (delete, cleanup, force operations, etc.) include explicit warnings in their descriptions:

```
DESTRUCTIVE OPERATION - ALWAYS ASK USER FOR EXPLICIT CONFIRMATION BEFORE EXECUTING.
[specific consequence]. This operation cannot be undone.
```

**Tools with destructive capabilities:**
- **c5t**: `delete_task`, `delete_task_list`, `delete_note`, `import_data` (replaces all data)
- **gh**: `delete_release` (deletes release + binaries), `close_pr` with `delete_branch`
- **k8s**: `kube_delete`, `helm_uninstall`, `kube_cleanup`, `kube_scale` (to 0)
- **ArgoCD**: `delete_application`, `sync_application` with `prune: true`

**LLM Agents**: These warnings instruct LLMs to ALWAYS ask for user permission before executing destructive operations. Never execute these tools without explicit user confirmation.

**Safety Modes**: Many tools implement safety modes (readonly/non-destructive/destructive) via environment variables. See individual tool READMEs for details.

## Installation

### Via Nix

#### As a Nix profile (standalone usage)

You can install this flake as a Nix profile:

```sh
nix profile install github:ck3mp3r/nu-mcp
```

Or, if you have a local checkout:

```sh
nix profile install path:/absolute/path/to/nu-mcp
```

#### Installing Tools

Tools are available as individual packages or as a complete collection:

##### Individual Tools
```sh
# Kubernetes tool only
nix profile install github:ck3mp3r/nu-mcp#k8s-mcp-tools

# ArgoCD tool only
nix profile install github:ck3mp3r/nu-mcp#argocd-mcp-tools

# Weather tool only
nix profile install github:ck3mp3r/nu-mcp#weather-mcp-tools

# Finance tool only  
nix profile install github:ck3mp3r/nu-mcp#finance-mcp-tools

# Tmux tool only
nix profile install github:ck3mp3r/nu-mcp#tmux-mcp-tools

# Context7 (c67) tool only
nix profile install github:ck3mp3r/nu-mcp#c67-mcp-tools
```

##### Complete Tool Collection
```sh
# All available tools
nix profile install github:ck3mp3r/nu-mcp#mcp-tools
```

Tools are installed to `~/.nix-profile/share/nushell/mcp-tools/`.

#### As an overlay in your own flake

Add this flake as an input and overlay in your `flake.nix`:

```nix
{
  inputs.nu-mcp.url = "github:ck3mp3r/nu-mcp";
  # ...
  outputs = { self, nixpkgs, nu-mcp, ... }:
    let
      overlays = [ nu-mcp.overlays.default ];
      pkgs = import nixpkgs { inherit system overlays; };
    in {
      # Now pkgs.nu-mcp is available
      packages.x86_64-linux.nu-mcp = pkgs.nu-mcp;
    };
}
```

You can now use `pkgs.nu-mcp` in your own packages, devShells, or CI.

### Via Homebrew (macOS and Linux)

Install from the tap:

```sh
brew tap ck3mp3r/nu-mcp https://github.com/ck3mp3r/nu-mcp
brew install nu-mcp
```

## Development
- See [modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk) for SDK details and advanced usage.
- The code is modular and fully async.
- Tests are in `tests/filter.rs`.

## Creating Tools

Tools are modular Nushell scripts organized in directories with a `mod.nu` entry file. See [docs/tool-development.md](docs/tool-development.md) for detailed guidance.

## Security

Commands execute within a configurable directory sandbox. See [docs/security.md](docs/security.md) for detailed security considerations.

## Documentation

- [Configuration Guide](docs/configuration.md) - Setup and configuration options
- [Tool Development](docs/tool-development.md) - Creating modular tools
- [Testing](docs/testing.md) - Testing and debugging tools
- [Architecture](docs/) - Additional technical documentation
