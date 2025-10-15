# Multiple Instances

You can run multiple instances with different tool sets and sandbox directories. This approach is recommended for organizing tools by domain and avoiding conflicts.

## Example Multi-Instance Setup

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

## Benefits of Multiple Instances

- **Tool Organization**: Group related functionality (weather, finance, development)
- **Conflict Avoidance**: Each instance provides distinct tools without name collisions
- **Security Isolation**: Different instances can have different sandbox directories
- **Clear Interface**: Clients see focused tool sets rather than everything mixed together
- **Scalability**: Easy to add new tool categories without affecting existing ones

## Important Notes

The `run_nushell` tool is automatically disabled in extension mode to prevent multiple instances from providing identical generic command execution tools, which would confuse MCP clients about which instance to use.