# Context7 Tool for nu-mcp

This tool provides access to Context7's up-to-date library documentation through the nu-mcp server, using the Context7 v2 API.

## What is Context7?

Context7 is a service that provides up-to-date code documentation and examples for libraries and frameworks. Instead of relying on LLM training data (which can be outdated), Context7 fetches current documentation directly from official sources with intelligent LLM-powered ranking.

## Features

- **resolve-library-id**: Search for libraries and get Context7-compatible library IDs
- **get-library-docs**: Fetch up-to-date documentation for a specific library
- **v2 API Integration**: Uses Context7's latest API with improved ranking and quality scores

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
- **Trust Score** (0-10): Source reputation indicator
- **Benchmark Score** (0-100): Quality indicator
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
- `context7CompatibleLibraryID` (required): The library ID from `resolve-library-id` (e.g., `/facebook/react`)
- `topic` (optional): Focus the docs on a specific topic (e.g., "hooks", "routing")
- `tokens` (optional): **Deprecated in v2** - included for backward compatibility but ignored

**Output:**
Up-to-date documentation text from Context7, intelligently ranked based on the topic/query.

**Example:**
```json
{
  "context7CompatibleLibraryID": "/facebook/react",
  "topic": "hooks"
}
```

**Note:** The `topic` parameter is used as the `query` parameter in v2 API for intelligent content ranking.

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
- **api.nu** - API interactions with Context7 service (v2 endpoints)
- **http-client.nu** - HTTP wrapper for testability
- **formatters.nu** - Output formatting utilities
- **utils.nu** - Helper functions and validation

## v2 API Migration

This tool uses Context7's v2 API which provides:

- **Intelligent ranking**: Results ranked by relevance to your query using LLM-powered analysis
- **Quality metrics**: Trust Score (0-10) and Benchmark Score (0-100) for library quality assessment
- **Improved search**: Separate libraryName and query parameters for better search results

### Breaking Changes from v1

- **Search endpoint**: Changed from `/v1/search` to `/v2/libs/search`
- **Documentation endpoint**: Changed from `/v1/{id}` to `/v2/context` with libraryId as query param
- **New required parameter**: `query` now required for intelligent content ranking
- **Removed parameter**: `tokens` parameter no longer supported (server-determined)

## Testing

Run the c67 test suite:

```bash
nix develop .#ci --command run-tool-tests
```

Or run c67 tests specifically:

```bash
nu tools/c67/tests/run_tests.nu
```

Test coverage includes:
- HTTP client wrapper mocking
- API v2 endpoint integration
- Response validation
- Formatter output

## Based On

This implementation is based on the official Context7 MCP server:
- GitHub: [upstash/context7](https://github.com/upstash/context7)
- Website: [context7.com](https://context7.com)

## License

MIT - Same as the original Context7 MCP server
