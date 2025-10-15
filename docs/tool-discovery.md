# Tool Discovery

The nu-mcp server automatically discovers tools in the specified `--tools-dir` by:

1. **Scanning directories**: Each subdirectory is checked for a `mod.nu` file
2. **Loading modules**: Directories with valid `mod.nu` files are loaded as tools
3. **Validation**: Each module must implement `list-tools` and `call-tool` functions
4. **Error handling**: Directories without `mod.nu` or with invalid modules are skipped

## Directory Requirements
- Must contain a `mod.nu` file as the entry point
- `mod.nu` must implement required MCP interface functions
- Helper modules (`.nu` files) are optional and imported via `use` statements

## Discovery Behavior
```
tools/
├── weather/           # ✅ Discovered (has mod.nu)
├── finance/           # ✅ Discovered (has mod.nu)  
├── broken_tool/       # ❌ Skipped (no mod.nu)
└── data.json          # ❌ Ignored (not a directory)
```

## Implementation Details

Tool discovery is implemented in `src/tools.rs` and occurs once at server startup. Failed tool modules are logged as warnings but don't prevent the server from starting or other tools from loading.