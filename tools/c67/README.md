# Context7 Tool for nu-mcp

This tool provides access to Context7's up-to-date library documentation through the nu-mcp server.

## What is Context7?

Context7 is a service that provides up-to-date code documentation and examples for libraries and frameworks. Instead of relying on LLM training data (which can be outdated), Context7 fetches current documentation directly from official sources.

## Features

- **resolve-library-id**: Search for libraries and get Context7-compatible library IDs
- **get-library-docs**: Fetch up-to-date documentation for a specific library

## Available Tools

### resolve-library-id

Resolves a package/product name to a Context7-compatible library ID.

**Input:**
- `libraryName` (required): The name of the library to search for (e.g., "react", "next.js", "supabase")

**Output:**
A formatted list of matching libraries with:
- Library ID (format: `/org/project`)
- Title and description
- Code snippet count
- Trust score
- Available versions

**Example:**
```json
{
  "libraryName": "react"
}
```

### get-library-docs

Fetches documentation for a specific library using its Context7-compatible ID.

**Input:**
- `context7CompatibleLibraryID` (required): The library ID from `resolve-library-id` (e.g., `/reactjs/react.dev`)
- `topic` (optional): Focus the docs on a specific topic (e.g., "hooks", "routing")
- `tokens` (optional): Maximum tokens to return (default: 5000, minimum: 1000)

**Output:**
Up-to-date documentation text from Context7.

**Example:**
```json
{
  "context7CompatibleLibraryID": "/reactjs/react.dev",
  "topic": "hooks",
  "tokens": 3000
}
```

## API Key (Optional)

While the tool works without an API key, you can get higher rate limits by:

1. Creating a free account at [context7.com/dashboard](https://context7.com/dashboard)
2. Setting the `CONTEXT7_API_KEY` environment variable

Example:
```bash
export CONTEXT7_API_KEY=ctx7sk_your_api_key_here
nu-mcp --tools-dir=./tools
```

## Usage with nu-mcp

Start the nu-mcp server with the tools directory:

```bash
nu-mcp --tools-dir=./tools
```

The Context7 tools will be available to MCP clients that connect to the server.

## Architecture

The tool is organized into modular Nushell scripts:

- **mod.nu** - Main entry point with tool registration and routing
- **api.nu** - API interactions with Context7 service
- **formatters.nu** - Output formatting utilities
- **utils.nu** - Helper functions

## Based On

This implementation is based on the official Context7 MCP server:
- GitHub: [upstash/context7](https://github.com/upstash/context7)
- Website: [context7.com](https://context7.com)

## License

MIT - Same as the original Context7 MCP server
