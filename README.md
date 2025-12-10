# nu-mcp: Model Context Protocol (MCP) Server for Nushell

This project exposes Nushell as an MCP server using the official Rust SDK (`rmcp`).

## Features
- Exposes a tool to run arbitrary Nushell commands via MCP
- Extensible tool system via Nushell scripts in modular directories
- Uses the official Model Context Protocol Rust SDK
- Security sandbox for safe command execution
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
- `--sandbox-dir=PATH` - Additional allowed directories (current directory always included)

### Example MCP Configuration
```yaml
nu-mcp:
  command: "nu-mcp"
  args: ["--tools-dir=./tools", "--sandbox-dir=/tmp", "--sandbox-dir=/nix/store"]
```
Note: Current working directory is always accessible. Use `--sandbox-dir` to grant access to additional directories.

For detailed configuration options and tool development, see the [documentation](docs/).

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
