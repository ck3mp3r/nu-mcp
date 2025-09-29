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
Load additional tools from Nushell scripts in a specified directory using `--tools-dir`. Each `.nu` file should implement:
- `main list-tools` - Return JSON array of tool definitions
- `main call-tool <tool_name> <args>` - Execute the specified tool

**Key Behavior**: When `--tools-dir` is used, the `run_nushell` tool is automatically disabled by default. This design prevents conflicts when running multiple specialized MCP server instances and provides a cleaner tool interface focused on the specific extensions.

### Hybrid Mode
Combine both core and extension tools by using `--tools-dir` with `--enable-run-nushell`. This gives you access to both the generic `run_nushell` command execution and your custom extension tools in a single server instance.

## Configuration

The `nu-mcp` server is configured via command-line arguments or by passing arguments as part of a process launch configuration.

### Options

#### Core Tool Options
- `--denied-cmds=CMD1,CMD2,...`
  Comma-separated list of denied commands (default: `rm,shutdown,reboot,poweroff,halt,mkfs,dd,chmod,chown`)
- `--allowed-cmds=CMD1,CMD2,...`
  Comma-separated list of allowed commands (takes precedence over denied)
- `--allow-sudo`
  Allow use of `sudo` (default: false)

#### Extension System Options
- `--tools-dir=PATH`
  Directory containing `.nu` extension scripts. When specified, the server automatically discovers and loads all `.nu` files in this directory as MCP tools. **Important**: Using this flag automatically disables the `run_nushell` tool by default to prevent conflicts between multiple MCP server instances and avoid confusion when the same server provides both generic command execution and specific tools.
- `--enable-run-nushell`
  Explicitly re-enable the `run_nushell` tool when using `--tools-dir`. This creates a hybrid mode where both extension tools and generic nushell command execution are available. Use with caution in multi-instance setups to avoid tool name conflicts.

#### Security Filter Options (for `run_nushell` only)
- `-P, --disable-run-nushell-path-traversal-check`
  Disable path traversal protection
- `-S, --disable-run-nushell-system-dir-check`
  Disable system directory access protection

### Example Configurations

#### Basic Core Mode
```yaml
nu-mcp-core:
  command: "nu-mcp"
  args:
    - "--denied-cmds=rm,reboot"
    - "--allowed-cmds=ls,cat,echo"
    - "--allow-sudo"
```

#### Extension Mode Only
```yaml
nu-mcp-tools:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
```

#### Hybrid Mode
```yaml
nu-mcp-hybrid:
  command: "nu-mcp"
  args:
    - "--tools-dir=/path/to/tools"
    - "--enable-run-nushell"
    - "--allowed-cmds=ls,cat,echo"
```

#### Multiple Specialized Instances
You can run multiple instances with different tool sets. This approach is recommended for organizing tools by domain and avoiding conflicts:

```yaml
# Weather and location services
nu-mcp-weather:
  command: "nu-mcp"
  args:
    - "--tools-dir=/opt/mcp-tools/weather"

# Financial data services
nu-mcp-finance:
  command: "nu-mcp"
  args:
    - "--tools-dir=/opt/mcp-tools/finance"

# Development tools with core access
nu-mcp-dev:
  command: "nu-mcp"
  args:
    - "--tools-dir=/opt/mcp-tools/dev"
    - "--enable-run-nushell"
    - "--allowed-cmds=git,cargo,npm,docker"
    - "-P"  # Allow file access for development
```

**Why Multiple Instances?**
- **Tool Organization**: Group related functionality (weather, finance, development)
- **Conflict Avoidance**: Each instance provides distinct tools without name collisions
- **Security Isolation**: Different instances can have different security policies
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

Extension tools are Nushell scripts (`.nu` files) placed in the tools directory. Each script must implement these functions:

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
- `tools/weather.nu` - Weather data using Open-Meteo API
- `tools/ticker.nu` - Stock prices using Yahoo Finance API

**Note**: The tools in the `tools/` directory are examples for demonstration purposes only. They are not intended for production use and may have limitations or reliability issues. Users should review, test, and modify these examples according to their specific requirements before using them in any production environment.

## Security Notes
- By default, dangerous commands are denied for `run_nushell`
- Allowed commands always take precedence over denied commands
- Sudo is disabled by default for safety
- Security filters only apply to the `run_nushell` tool, not extensions
- Extensions run in the same security context as the server process

## Disclaimer

**USE AT YOUR OWN RISK**: This software is provided "as is" without warranty of any kind. The author(s) accept no responsibility or liability for any damage, data loss, security breaches, or other issues that may result from using this software. Users are solely responsible for:

- Reviewing and understanding the security implications before deployment
- Properly configuring access controls and command restrictions
- Testing thoroughly in non-production environments
- Monitoring and securing their systems when running this software
- Any consequences resulting from the execution of commands or scripts

By using this software, you acknowledge that you understand these risks and agree to use it at your own discretion and responsibility.
