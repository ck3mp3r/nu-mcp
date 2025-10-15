# nu-mcp: Model Context Protocol (MCP) Server for Nushell

This project exposes Nushell as an MCP server using the official Rust SDK (`rmcp`).

## Features
- Exposes a tool to run arbitrary Nushell commands via MCP
- Extensible tool system via Nushell scripts
- Uses the official Model Context Protocol Rust SDK
- Highly configurable: supports allowed/denied command lists and sudo control
- Security filters for safe command execution

## Operating Modes

### Core Mode (Default)
Provides the `run_nushell` tool for executing arbitrary Nushell commands.

### Extension Mode
Load additional tools from Nushell modules in a specified directory using `--tools-dir`. Each tool module should be a directory containing a `mod.nu` file that implements:
- `main list-tools` - Return JSON array of tool definitions
- `main call-tool <tool_name> <args>` - Execute the specified tool

**Key Behavior**: When `--tools-dir` is used, the `run_nushell` tool is automatically disabled by default. This design prevents conflicts when running multiple specialized MCP server instances and provides a cleaner tool interface focused on the specific extensions.

### Hybrid Mode
Combine both core and extension tools by using `--tools-dir` with `--enable-run-nushell`. This gives you access to both the generic `run_nushell` command execution and your custom extension tools in a single server instance.

## Configuration

The `nu-mcp` server is configured via command-line arguments or by passing arguments as part of a process launch configuration.

### Options

#### Extension System Options
- `--tools-dir=PATH`
  Directory containing tool modules. When specified, the server automatically discovers and loads all directories containing `mod.nu` files as MCP tools. **Important**: Using this flag automatically disables the `run_nushell` tool by default to prevent conflicts between multiple MCP server instances and avoid confusion when the same server provides both generic command execution and specific tools.
- `--enable-run-nushell`
  Explicitly re-enable the `run_nushell` tool when using `--tools-dir`. This creates a hybrid mode where both extension tools and generic nushell command execution are available. Use with caution in multi-instance setups to avoid tool name conflicts.

#### Security Options
- `--sandbox-dir=PATH`
  Directory to sandbox nushell execution (default: current working directory). Commands are restricted to this directory and cannot access parent directories or absolute paths outside the sandbox.

### Example Configurations

#### Basic Core Mode
```yaml
nu-mcp-core:
  command: "nu-mcp"
  args:
    - "--sandbox-dir=/safe/workspace"
```

#### Extension Mode Only
```yaml
nu-mcp-tools:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--sandbox-dir=/safe/workspace"
```

#### Hybrid Mode
```yaml
nu-mcp-hybrid:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--enable-run-nushell"
    - "--sandbox-dir=/safe/workspace"
```

#### Multiple Specialized Instances
You can run multiple instances with different tool sets and sandbox directories. This approach is recommended for organizing tools by domain and avoiding conflicts:

```yaml
# Weather and location services
nu-mcp-weather:
  command: "nu-mcp"
  args:
    - "--tools-dir=/opt/mcp-tools/weather"
    - "--sandbox-dir=/tmp/weather-workspace"

# Financial data services
nu-mcp-finance:
  command: "nu-mcp"
  args:
    - "--tools-dir=/opt/mcp-tools/finance"
    - "--sandbox-dir=/tmp/finance-workspace"

# Development tools with sandbox access
nu-mcp-dev:
  command: "nu-mcp"
  args:
    - "--tools-dir=/opt/mcp-tools/dev"
    - "--enable-run-nushell"
    - "--sandbox-dir=/workspace/project"
```

**Why Multiple Instances?**
- **Tool Organization**: Group related functionality (weather, finance, development)
- **Conflict Avoidance**: Each instance provides distinct tools without name collisions
- **Security Isolation**: Different instances can have different sandbox directories
- **Clear Interface**: Clients see focused tool sets rather than everything mixed together
- **Scalability**: Easy to add new tool categories without affecting existing ones

**Note**: The `run_nushell` tool is automatically disabled in extension mode to prevent multiple instances from providing identical generic command execution tools, which would confuse MCP clients about which instance to use.

## Installation

### As a Nix profile (standalone usage)

You can install this flake as a Nix profile:

```sh
nix profile install github:ck3mp3r/nu-mcp
```

Or, if you have a local checkout:

```sh
nix profile install path:/absolute/path/to/nu-mcp
```

### Installing Example Tools

Example tools are available as a separate package and will be installed to `~/.nix-profile/share/nushell/mcp-tools/examples`:

```sh
nix profile install github:ck3mp3r/nu-mcp#mcp-example-tools
```

### As an overlay in your own flake

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

## Development
- See [modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk) for SDK details and advanced usage.
- The code is modular and fully async.
- Tests are in `tests/filter.rs`.

## Creating Extension Tools

Extension tools are Nushell modules organized as directories with a `mod.nu` entry file in the tools directory. Each module's `mod.nu` file must implement these functions:

### Required Functions

```nushell
# List available MCP tools
def "main list-tools" [] {
    [
        {
            name: "tool_name",
            description: "Tool description",
            input_schema: {
                type: "object",
                properties: {
                    param: {
                        type: "string",
                        description: "Parameter description"
                    }
                },
                required: ["param"]
            }
        }
    ] | to json
}

# Execute a tool
def "main call-tool" [
    tool_name: string
    args: string = "{}"
] {
    let parsed_args = $args | from json
    match $tool_name {
        "tool_name" => { your_function ($parsed_args | get param) }
        _ => { error make {msg: $"Unknown tool: ($tool_name)"} }
    }
}
```

### Example Tool Structure

See the included example tools:
- `tools/weather/mod.nu` - Weather data using Open-Meteo API
- `tools/finance/mod.nu` - Stock prices using Yahoo Finance API

Tool modules can contain additional helper files alongside `mod.nu`:
```
tools/
├── weather/
│   ├── mod.nu          # Entry point implementing list-tools/call-tool
│   ├── geocoding.nu    # Helper module for location services
│   └── api.nu          # Helper module for API interactions
└── finance/
    ├── mod.nu          # Entry point
    └── utils.nu        # Shared utilities
```

**Note**: The tools in the `tools/` directory are examples for demonstration purposes only. They are not intended for production use and may have limitations or reliability issues. Users should review, test, and modify these examples according to their specific requirements before using them in any production environment.

## Security Notes
- Commands execute within a directory sandbox (configurable with `--sandbox-dir`)
- Path traversal patterns (`../`) are blocked to prevent escaping the sandbox
- Absolute paths outside the sandbox directory are blocked
- Extensions run in the same security context as the server process
- The sandbox provides directory isolation but does not restrict system resources, network access, or process spawning

## Disclaimer

**USE AT YOUR OWN RISK**: This software is provided "as is" without warranty of any kind. The author(s) accept no responsibility or liability for any damage, data loss, security breaches, or other issues that may result from using this software. Users are solely responsible for:

- Reviewing and understanding the security implications before deployment
- Properly configuring sandbox directories and access controls
- Testing thoroughly in non-production environments
- Monitoring and securing their systems when running this software
- Any consequences resulting from the execution of commands or scripts

By using this software, you acknowledge that you understand these risks and agree to use it at your own discretion and responsibility.
