# Tool Development Guide

Tools are Nushell modules organized as directories with a `mod.nu` entry file in the tools directory. Each module's `mod.nu` file must implement the MCP interface functions.

## Required Functions

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

## Modular Tool Structure

Tool modules can contain additional helper files alongside `mod.nu`:

```
tools/
├── weather/
│   ├── mod.nu          # Entry point implementing list-tools/call-tool
│   ├── geocoding.nu    # Location services and coordinate lookup
│   ├── api.nu          # Weather API interactions and validation
│   └── formatters.nu   # Data formatting and conversion utilities
└── finance/
    ├── mod.nu          # Entry point implementing list-tools/call-tool
    ├── yahoo_api.nu    # Yahoo Finance API interactions and validation
    ├── utils.nu        # Financial calculations and formatting utilities
    └── formatters.nu   # Stock data display formatting and error handling
```

## Best Practices for Helper Modules

1. **Use descriptive module names**: `api.nu`, `formatters.nu`, `utils.nu`, `geocoding.nu`
2. **Export functions explicitly**: Use `export def function_name` for public functions
3. **Import modules in mod.nu**: Use `use module_name.nu *` to import all exports
4. **Separate concerns**: Keep related functionality together (API calls, formatting, calculations)

## Example Modular Structure

### Simple Tool (single functionality)
```
tools/simple_tool/
└── mod.nu              # All functionality in entry point
```

### Complex Tool (multiple responsibilities)
```
tools/weather/
├── mod.nu              # Entry point with MCP interface
├── geocoding.nu        # Location services
├── api.nu              # External API interactions
└── formatters.nu       # Data display formatting
```

## Helper Module Example

**formatters.nu:**
```nushell
# Export functions for use in other modules
export def format_temperature [temp: float] {
  $"($temp)°C"
}

export def format_weather_data [data: record] {
  # formatting logic here
}
```

**mod.nu:**
```nushell
# Import helper modules
use formatters.nu *
use api.nu *

def "main call-tool" [tool_name: string, args: string = "{}"] {
  let parsed_args = $args | from json
  match $tool_name {
    "get_weather" => {
      get_weather ($parsed_args | get location)
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}
```

## Module Organization Guidelines

- **API modules**: Handle external service interactions and response validation
- **Formatter modules**: Handle data display, conversion, and output formatting
- **Utility modules**: Handle calculations, data processing, and common functions
- **Domain modules**: Handle domain-specific logic (e.g., geocoding, financial calculations)