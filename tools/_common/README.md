# Common MCP Tools Library

Shared utilities for all MCP tools.

## Modules

### `toon.nu` - TOON Encoder

Token-Oriented Object Notation (TOON) encoder for reducing token usage by 30-60% compared to JSON.

**Usage:**

```nushell
use toon.nu *

# Encode table data
[{id: 1, name: "Alice"}, {id: 2, name: "Bob"}] | to toon
# Output:
# [2,]{id,name}:
#   1,Alice
#   2,Bob

# Encode record
{name: "Alice", age: 30} | to toon
# Output:
# name: Alice
# age: 30
```

## Using in Tools

Since tools are packaged separately by Nix, you cannot use relative imports. Instead, the common library is installed alongside other tools.

**In development (relative import):**

```nushell
use ../_common/toon.nu *
```

**After Nix packaging:**

Both `_common` and your tool will be in the same parent directory (`/nix/store/.../share/nushell/mcp-tools/`), so the relative import works at runtime.

## Benefits

- **Single source of truth**: Update once, all tools benefit
- **Token efficiency**: TOON format reduces LLM token usage
- **No duplication**: Common utilities in one place
- **Immutable packaging**: Works with Nix's immutable store
