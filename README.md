# nu-mcp: Model Context Protocol (MCP) Server for Nushell

This project exposes Nushell as an MCP server using the official Rust SDK (`rmcp`).

## Features
- Exposes a tool to run arbitrary Nushell commands via MCP
- Uses the official Model Context Protocol Rust SDK
- Ready for integration with Claude Desktop, Perplexity, and other MCP clients

## Usage

### Build
```sh
cargo build --release
```

### Run
```sh
cargo run --release
```

### Example MCP Tool Call
- `run_nushell {"command": "ls"}`

## Development
- See [modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk) for SDK details and advanced usage.

## Migration Notes
- The previous command filtering logic has been removed in favor of direct Nushell access via MCP tools.
- The code is now fully async and MCP-compliant.
- See `.backup/main.rs.bak` for the old implementation.
