# Testing Tools

## Testing Individual Modules
```bash
# Test a specific module function
cd tools/weather
nu -c "use formatters.nu *; format_temperature 25.5"

# Test module independently
cd tools/finance
nu -c "use utils.nu *; calculate_price_change 100.0 95.0"
```

## Testing Complete Tools
```bash
# Test tool discovery
nu tools/weather/mod.nu list-tools

# Test tool execution
nu tools/weather/mod.nu call-tool get_weather '{"location": "London"}'
nu tools/finance/mod.nu call-tool get_ticker_price '{"symbol": "AAPL"}'
```

## Integration Testing
```bash
# Test with nu-mcp server (requires build)
cargo build
./target/debug/nu-mcp --tools-dir=./tools
```

## Testing with Test Directory
The project includes test tools in `test/tools/` for development and validation:

- `test/tools/simple/` - Basic tool implementation example
- `test/tools/math/` - Mathematical operations tool
- `test/tools/empty/` - Empty tool for testing discovery
- `test/tools/invalid/` - Invalid tool for error handling tests
- `test/tools/no-mod-file/` - Directory without mod.nu for testing discovery

```bash
# Test tool discovery with test tools
./target/debug/nu-mcp --tools-dir=./test/tools

# Test specific test tools
nu test/tools/math/mod.nu list-tools
nu test/tools/simple/mod.nu call-tool simple_echo '{"message": "hello"}'
```

## Troubleshooting

### Common Issues

**Tool not discovered:**
- Verify `mod.nu` file exists in tool directory
- Check that `list-tools` function returns valid JSON
- Review server logs for discovery warnings

**Tool execution fails:**
- Ensure `call-tool` function handles all declared tools
- Validate JSON argument parsing in tool implementation
- Check that all required helper modules are present

**Module import errors:**
- Verify `use` statements reference existing `.nu` files
- Ensure exported functions use `export def` syntax
- Check that helper modules are in the same directory as `mod.nu`

### Debug Commands
```bash
# Test tool discovery manually
nu path/to/tool/mod.nu list-tools

# Test tool execution manually  
nu path/to/tool/mod.nu call-tool tool_name '{"param": "value"}'

# Check module syntax
nu -c "use path/to/helper.nu *; help commands | where name =~ helper"
```