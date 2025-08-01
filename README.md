# nu-mcp: Model Context Protocol (MCP) Server for Nushell

This project exposes Nushell as an MCP server using the official Rust SDK (`rmcp`).

## Features
- Exposes a tool to run arbitrary Nushell commands via MCP
- Uses the official Model Context Protocol Rust SDK
- Highly configurable: supports allowed/denied command lists and sudo control

## Configuration

The `nu-mcp` server is configured via command-line arguments or by passing arguments as part of a process launch configuration.

### Options
- `--denied-cmds=CMD1,CMD2,...`  
  Comma-separated list of denied commands (default: `rm,shutdown,reboot,poweroff,halt,mkfs,dd,chmod,chown`)
- `--allowed-cmds=CMD1,CMD2,...`  
  Comma-separated list of allowed commands (takes precedence over denied)
- `--allow-sudo`  
  Allow use of `sudo` (default: false)

### Example YAML Process Configuration

If you want to launch `nu-mcp` as a subprocess from a supervisor or orchestrator, you might use a YAML like:

```yaml
nu-mcp:
  command: "nu-mcp"
  args:
    - "--denied-cmds=rm,reboot"
    - "--allowed-cmds=ls,cat"
    - "--allow-sudo"
```

## Development
- See [modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk) for SDK details and advanced usage.
- The code is modular and fully async.
- Tests are in `tests/filter.rs`.

## Security Notes
- By default, dangerous commands are denied.
- Allowed commands always take precedence over denied commands.
- Sudo is disabled by default for safety.
