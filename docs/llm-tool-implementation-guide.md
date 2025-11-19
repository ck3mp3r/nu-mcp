# LLM Guide: Implementing New Tools for nu-mcp

## Quick Reference

**Before you start:**
1. ✅ Use Context7 to research APIs/libraries
2. ✅ Create implementation plan in `docs/implementation-plans/`
3. ✅ Create feature branch: `git checkout -b feature/<tool-name>`

**Naming conventions:**
- Tool names (MCP): `snake_case` → `get_weather`, `list_sessions`
- Function names (Nushell): `kebab-case` → `get-current-weather`, `validate-input`
- File names: `kebab-case` or `snake_case` (be consistent)

**Required files:**
- `tools/<tool-name>/mod.nu` - MCP interface (list-tools, call-tool)
- `tools/<tool-name>/README.md` - User documentation

**Common module pattern:**
- `api.nu` - External API calls, HTTP interactions
- `formatters.nu` - Display formatting, text output
- `utils.nu` - Helper functions, calculations

## IMPORTANT: Pre-Implementation Steps

### 1. Research with Context7
**ALWAYS** use Context7 to research relevant libraries and APIs before writing code:

```
Use context7_resolve_library_id to find the library
Use context7_get_library_docs to get documentation for:
- External APIs you'll be calling
- Nushell standard library functions
- Any third-party integrations
```

This ensures you use current best practices and correct API patterns.

### 2. Create a Planning Document
**BEFORE** writing any code, create a Markdown planning document at:
```
docs/implementation-plans/<tool-name>-implementation-plan.md
```

This plan must include:
- Tool overview and purpose
- List of capabilities (what tools/functions will be exposed)
- External dependencies (APIs, CLI tools, etc.)
- Module structure breakdown
- Iterative milestones that can be checked off
- Security considerations
- Error handling strategy
- Testing approach

### 3. Create a Feature Branch
**ALWAYS** create a new Git branch before starting implementation:
```bash
git checkout -b feature/<tool-name>
```

Never commit directly to main. All tool development should happen in feature branches.

## Naming Conventions

### CRITICAL: Follow Nushell Naming Standards

**Tool Names (MCP exposed)**: Use `snake_case`
```nushell
# ✅ Correct - Tool names in snake_case
{
    name: "get_weather"        # Good
    name: "sync_application"   # Good
    name: "list_sessions"      # Good
}

# ❌ Incorrect
{
    name: "getWeather"         # Wrong - camelCase
    name: "sync-application"   # Wrong - kebab-case
    name: "ListSessions"       # Wrong - PascalCase
}
```

**Function Names (Nushell internal)**: Use `kebab-case`
```nushell
# ✅ Correct - Functions in kebab-case
export def get-current-weather [lat: float, lon: float] { }
export def validate-api-response [response: record] { }
def format-temperature [temp: float] { }
def build-api-url [params: record] { }

# ❌ Incorrect
export def get_current_weather [lat: float, lon: float] { }  # Wrong - snake_case
export def getCurrentWeather [lat: float, lon: float] { }    # Wrong - camelCase
export def ValidateApiResponse [response: record] { }        # Wrong - PascalCase
```

**Why This Matters:**
- **Tool names** are exposed to LLMs via MCP - `snake_case` is standard in MCP/JSON APIs
- **Function names** are Nushell-internal - `kebab-case` is Nushell's standard convention
- Consistency helps both humans and LLMs understand the codebase

**Complete Example:**
```nushell
# mod.nu
def "main list-tools" [] {
    [
        {
            name: "get_ticker_price"  # snake_case for MCP tool name
            description: "Get stock price"
            input_schema: { ... }
        }
    ] | to json
}

def "main call-tool" [tool_name: string, args: any] {
    match $tool_name {
        "get_ticker_price" => {      # snake_case tool name
            get-ticker-price $args   # kebab-case function name
        }
    }
}

# Implementation function in kebab-case
def get-ticker-price [symbol: string] {  # kebab-case
    let data = fetch-stock-data $symbol  # kebab-case
    format-stock-output $data             # kebab-case
}

# Helper functions also in kebab-case
def fetch-stock-data [symbol: string] { }
def format-stock-output [data: record] { }
```

**File Names**: Use `kebab-case` or `snake_case` consistently
- Common pattern: `kebab-case` (e.g., `formatters.nu`, `yahoo-api.nu`)
- Also acceptable: `snake_case` (e.g., `formatters.nu`, `yahoo_api.nu`)
- Be consistent within your tool module

## Architecture Overview

### How nu-mcp Discovers and Loads Tools

The Rust application uses a **convention-based discovery system**:

1. **Discovery Phase** (`src/tools/discovery.rs:16-62`)
   - Scans the `tools_dir` (default: `./tools`)
   - Looks for directories containing `mod.nu` files
   - Each `mod.nu` is executed with `nu mod.nu list-tools`
   - Tools that fail to load are logged as warnings but don't stop server startup

2. **Tool Registration** (`src/mcp/mod.rs:64-120`)
   - Discovered tools are registered with the MCP server
   - Each tool's schema is stored in memory
   - Tools are exposed via the `list_tools` MCP endpoint

3. **Tool Execution** (`src/tools/execution.rs:20-52`)
   - When called, executes `nu mod.nu call-tool <tool_name> <args_json>`
   - Each invocation spawns a new Nushell process (no caching)
   - JSON arguments are passed as a string
   - JSON output is returned to the caller

### The Tool Contract

Every tool module **MUST** implement two subcommands in `mod.nu`:

```nushell
# 1. Tool Discovery - Returns JSON array of tool definitions
def "main list-tools" [] {
    # Returns: JSON array of tool schemas
}

# 2. Tool Execution - Executes a named tool with arguments
def "main call-tool" [
    tool_name: string
    args: any = "{}"  # Can be string or record
] {
    # Returns: Tool output (any format)
}
```

## SOLID Principles Applied to Nushell Tools

### Single Responsibility Principle (SRP)
**Each module file should have ONE clear purpose:**

- ✅ **Good**: Separate `api.nu`, `formatters.nu`, `utils.nu`
- ❌ **Bad**: All logic in `mod.nu`

**Module Responsibilities:**
- `mod.nu`: MCP interface (list-tools, call-tool), argument routing
- `api.nu`: External API calls, HTTP interactions, response validation
- `formatters.nu`: Data display, text formatting, unit conversions
- `utils.nu`: Calculations, data transformations, helper functions
- Domain-specific modules: `geocoding.nu`, `session.nu`, etc.

### Open/Closed Principle (OCP)
**Design for extension without modification:**

```nushell
# ✅ Good: Easy to add new tools without changing structure
def "main call-tool" [tool_name: string, args: any] {
    match $tool_name {
        "tool_one" => { tool_one_impl $args }
        "tool_two" => { tool_two_impl $args }
        # New tools added here - existing code unchanged
        _ => { error make {msg: $"Unknown tool: ($tool_name)"} }
    }
}

# ✅ Good: Formatters that accept data, don't know about sources
export def format_data [data: record] {
    # Format any data, regardless of where it came from
}
```

### Liskov Substitution Principle (LSP)
**Consistent interfaces across similar operations:**

```nushell
# ✅ All validation functions return same structure
export def validate_location [location: string] {
    if (is_valid $location) {
        { valid: true, data: $result }
    } else {
        { valid: false, error: "error message" }
    }
}

export def validate_api_response [response: any] {
    if (is_valid $response) {
        { valid: true, data: $response }
    } else {
        { valid: false, error: "error message" }
    }
}
```

### Interface Segregation Principle (ISP)
**Export only what's needed, keep implementation details private:**

```nushell
# api.nu - Only export high-level operations (kebab-case function names)
export def get-weather-data [lat: float, lon: float] {
    # Implementation uses private helpers
    let url = (build-api-url $lat $lon)  # Private helper (kebab-case)
    fetch-and-validate $url              # Private helper (kebab-case)
}

# Don't export: build-api-url, fetch-and-validate
# These are internal implementation details
```

### Dependency Inversion Principle (DIP)
**Depend on abstractions (records/interfaces) not concrete implementations:**

```nushell
# ✅ Good: Function accepts generic record with required fields (kebab-case)
export def format-weather [data: record] {
    # Expects data.temperature, data.humidity, etc.
    # Doesn't care if it came from OpenMeteo, Weather.gov, etc.
}

# ✅ Good: Validation returns standard structure (kebab-case)
export def validate-input [input: any] -> record<valid: bool, data?: any, error?: string> {
    # Callers can depend on this structure
}
```

## Idiomatic Nushell Patterns

### 1. Argument Parsing Pattern
```nushell
def "main call-tool" [
    tool_name: string
    args: any = {}
] {
    # Handle both string (from Rust) and record (from direct calls)
    let parsed_args = if ($args | describe) == "string" {
        $args | from json
    } else {
        $args
    }
    
    # Extract with defaults for optional parameters
    let required_param = $parsed_args | get required_param
    let optional_param = if "optional_param" in $parsed_args { 
        $parsed_args | get optional_param 
    } else { 
        default_value 
    }
}
```

### 2. Error Handling Pattern
```nushell
# ✅ Use try-catch with structured error records (kebab-case)
export def api-call [url: string] {
    try {
        http get $url
    } catch { |err|
        {
            success: false
            error: $"API call failed: ($err.msg)"
        }
    }
}

# ✅ Validate and return structured results (kebab-case)
export def validate-data [data: any] {
    if (is-valid $data) {
        { valid: true, data: $data }
    } else {
        { valid: false, error: "validation failed" }
    }
}

# ✅ Propagate errors to caller (kebab-case)
def tool-function [input: string] {
    let result = validate-input $input
    if not $result.valid {
        return $result.error  # Return error string to user
    }
    # Continue with valid data
}
```

### 3. Module Import Pattern
```nushell
# In mod.nu - Import all exports from helper modules
use api.nu *
use formatters.nu *
use utils.nu *

# In helper modules - Export public functions (kebab-case)
export def public-function [] { ... }

# Private functions (no export, also kebab-case)
def private-helper [] { ... }
```

### 4. Data Pipeline Pattern
```nushell
# ✅ Idiomatic: Chain transformations (kebab-case)
export def get-and-format-data [input: string] {
    validate-input $input
    | get-api-data
    | transform-response
    | format-for-display
}

# Each function in chain takes input, returns output
# Errors propagate naturally
```

### 5. Parameter Handling Pattern
```nushell
# ✅ Use null for optional parameters (kebab-case)
export def flexible-function [
    required: string
    optional?: string  # Optional with ?
    with_default: string = "default"  # Default value
] {
    let opt_value = if $optional != null { 
        $optional 
    } else { 
        "fallback" 
    }
}
```

### 6. Record Building Pattern
```nushell
# ✅ Build records progressively (kebab-case)
export def create-response [data: record, meta: record] {
    {
        timestamp: (date now | format date "%Y-%m-%d %H:%M:%S")
        data: $data
        metadata: $meta
        status: "success"
    }
}
```

### 7. List Processing Pattern
```nushell
# ✅ Use idiomatic list operations (kebab-case)
export def process-items [items: list] {
    $items
    | where { |item| $item.valid }
    | each { |item| transform $item }
    | filter { |item| $item != null }
    | sort-by name
}
```

## Common Patterns in Existing Tools

### Pattern 1: Simple Tool (Finance, Weather)
**Structure:**
```
tool-name/
├── mod.nu              # MCP interface
├── api.nu              # External API interactions
├── formatters.nu       # Display formatting
└── utils.nu            # Helper functions (optional)
```

**Characteristics:**
- Single external API or data source
- Focused functionality (1-3 tools exposed)
- Stateless operations
- Simple data transformations

### Pattern 2: Complex Tool with Safety Modes (Kubernetes, ArgoCD)
**Structure:**
```
tool-name/
├── mod.nu              # MCP interface + safety checking
├── utils.nu            # CLI wrapper, safety checks, env config
├── formatters.nu       # Response formatting, error messages
├── resources.nu        # Resource-specific operations
├── operations.nu       # CRUD operations
└── README.md           # User documentation
```

**Characteristics:**
- Multiple safety modes (read-only, non-destructive, destructive)
- Environment variable configuration
- CLI tool wrapping (kubectl, argocd)
- Extensive error handling
- Permission checking before execution

**Safety Mode Implementation:**
```nushell
# utils.nu
export def get-safety-mode [] {
    $env.MCP_TOOL_MODE? | default "readonly"
}

export def readonly-tools [] {
    ["get_resource", "list_items", "describe_item"]
}

export def destructive-tools [] {
    ["delete_resource", "cleanup", "force_update"]
}

export def is-tool-allowed [tool_name: string] {
    let mode = get-safety-mode
    match $mode {
        "readonly" => { $tool_name in (readonly-tools) }
        "non-destructive" => { $tool_name not-in (destructive-tools) }
        "destructive" => { true }
        _ => { false }
    }
}

# mod.nu
def "main call-tool" [tool_name: string, args: any] {
    if not (is-tool-allowed $tool_name) {
        error make {
            msg: $"Tool '($tool_name)' not allowed in current mode"
        }
    }
    # ... proceed with execution
}
```

### Pattern 3: Interactive Tool (Tmux)
**Structure:**
```
tool-name/
├── mod.nu              # MCP interface
├── core.nu             # Basic operations
├── session.nu          # Session management
├── commands.nu         # Command execution
├── process.nu          # Process info
├── search.nu           # Search/discovery
└── README.md
```

**Characteristics:**
- Multiple related capabilities
- State management (sessions, panes)
- Search and discovery features
- Complex targeting (by name, ID, context)

## Tool Schema Definition

### JSON Schema Structure
```nushell
def "main list-tools" [] {
    [
        {
            name: "tool_name"  # Snake_case, unique within module
            description: "Clear, concise description of what this tool does"
            input_schema: {
                type: "object"
                properties: {
                    required_param: {
                        type: "string"  # string, integer, number, boolean, object, array
                        description: "Clear description for LLM consumption"
                    }
                    optional_param: {
                        type: "integer"
                        description: "Description with default behavior"
                        minimum: 1  # Constraints for validation
                        maximum: 100
                    }
                    enum_param: {
                        type: "string"
                        description: "Parameter with limited values"
                        enum: ["option1", "option2", "option3"]
                    }
                }
                required: ["required_param"]  # List of required fields
                additionalProperties: false   # Reject unknown properties (optional)
            }
        }
    ] | to json
}
```

### Schema Best Practices
1. **Descriptive names**: Use clear, action-oriented names (`get_weather`, `sync_application`)
2. **Detailed descriptions**: Write for LLM consumption - be explicit about behavior
3. **Appropriate types**: Use correct JSON Schema types
4. **Constraints**: Add `minimum`, `maximum`, `enum`, `pattern` where applicable
5. **Required fields**: Only mark truly required fields as required
6. **Defaults in description**: Document default values in descriptions

## Error Handling Strategy

### Levels of Error Handling

**Level 1: Input Validation (mod.nu)**
```nushell
def "main call-tool" [tool_name: string, args: any] {
    # Parse JSON
    let parsed_args = try {
        if ($args | describe) == "string" { $args | from json } else { $args }
    } catch {
        return "Error: Invalid JSON arguments"
    }
    
    # Validate required parameters
    if "required_param" not-in $parsed_args {
        return "Error: Missing required parameter 'required_param'"
    }
    
    # Route to tool
}
```

**Level 2: Business Logic Validation (utils.nu, api.nu)**
```nushell
# kebab-case for function names
export def validate-location [location: string] {
    if ($location | str length) < 2 {
        return {
            valid: false
            error: "Location must be at least 2 characters"
        }
    }
    
    # API call to validate
    let result = try {
        api-lookup $location
    } catch {
        return {
            valid: false
            error: $"Location lookup failed: ($in)"
        }
    }
    
    { valid: true, data: $result }
}
```

**Level 3: API Error Handling (api.nu)**
```nushell
# kebab-case for function names
export def call-external-api [url: string] {
    try {
        let response = http get $url
        { success: true, data: $response }
    } catch { |err|
        {
            success: false
            error: $"API call failed: ($err.msg)"
            details: $err
        }
    }
}
```

**Level 4: Response Formatting (formatters.nu)**
```nushell
# kebab-case for function names
export def format-error [context: string, error: string] {
    $"Error in ($context): ($error)

Please check:
- Input parameters are correct
- External service is available
- Environment variables are set (if required)

See README.md for more information."
}
```

### Error Handling Checklist
- [ ] JSON parsing errors caught and reported
- [ ] Required parameters validated
- [ ] Business logic validation with clear messages
- [ ] API/CLI errors caught with context
- [ ] User-friendly error messages
- [ ] Errors don't expose sensitive information
- [ ] Errors guide user toward resolution

## Step-by-Step Implementation Process

### Phase 1: Planning & Research
**Create**: `docs/implementation-plans/<tool-name>-implementation-plan.md`

```markdown
# <Tool Name> Implementation Plan

## Overview
- **Purpose**: What problem does this tool solve?
- **Target Users**: Who will use this?
- **External Dependencies**: APIs, CLIs, libraries needed

## Capabilities
- [ ] Capability 1: Description
- [ ] Capability 2: Description
- [ ] Capability 3: Description

## Module Structure
- `mod.nu`: MCP interface and routing
- `api.nu`: [Describe responsibility]
- `formatters.nu`: [Describe responsibility]
- `utils.nu`: [Describe responsibility]

## Context7 Research
- [ ] Research API: <library-name>
- [ ] Research Nushell functions: http, json, etc.
- [ ] Research similar MCP tools

## Security Considerations
- Safety mode required? (readonly/non-destructive/destructive)
- Sensitive data handling?
- Rate limiting needed?

## Milestones
- [ ] Milestone 1: Basic module structure and mod.nu skeleton
- [ ] Milestone 2: API integration in api.nu
- [ ] Milestone 3: First working tool
- [ ] Milestone 4: Error handling and validation
- [ ] Milestone 5: Additional tools
- [ ] Milestone 6: Formatters and user-friendly output
- [ ] Milestone 7: Documentation and README
- [ ] Milestone 8: Testing and edge cases

## Testing Approach
- Manual testing commands
- Edge cases to verify
- Error scenarios to test

## Questions & Decisions
- Open questions
- Design decisions with rationale
```

### Phase 2: Branch Creation
```bash
git checkout -b feature/<tool-name>
```

### Phase 3: Milestone 1 - Basic Structure
**Create directory and skeleton:**
```bash
mkdir -p tools/<tool-name>
touch tools/<tool-name>/mod.nu
```

**Create basic mod.nu:**
```nushell
# <Tool Name> for nu-mcp - <one-line description>

def main [] {
    help main
}

def "main list-tools" [] {
    [
        # Tools will be added here
    ] | to json
}

def "main call-tool" [
    tool_name: string
    args: any = {}
] {
    let parsed_args = if ($args | describe) == "string" {
        $args | from json
    } else {
        $args
    }
    
    match $tool_name {
        _ => {
            error make {msg: $"Unknown tool: ($tool_name)"}
        }
    }
}
```

**Update plan:**
- [ ] ✅ Milestone 1: Basic module structure and mod.nu skeleton

### Phase 4: Milestone 2 - API Integration
**Research with Context7:**
```
Use Context7 to research the external API or CLI tool
Document findings in the implementation plan
```

**Create api.nu (if needed):**
```nushell
# API interaction module
# NOTE: Use kebab-case for ALL function names

# Main API call function (kebab-case)
export def call-api [param: string] {
    let url = build-url $param
    
    try {
        let response = http get $url
        { success: true, data: $response }
    } catch { |err|
        {
            success: false
            error: $"API call failed: ($err.msg)"
        }
    }
}

# URL builder (private, also kebab-case)
def build-url [param: string] {
    $"https://api.example.com/endpoint?q=($param)"
}

# Response validator (kebab-case)
export def validate-response [response: record] {
    if $response.success != true {
        return { valid: false, error: $response.error }
    }
    
    # Check required fields exist
    let required_fields = ["field1", "field2"]
    let data = $response.data
    let missing = $required_fields | where { |f| $f not-in $data }
    
    if ($missing | length) > 0 {
        {
            valid: false
            error: $"Missing fields: ($missing | str join ', ')"
        }
    } else {
        { valid: true, data: $data }
    }
}
```

**Update mod.nu to import:**
```nushell
use api.nu *
```

**Update plan:**
- [ ] ✅ Milestone 2: API integration in api.nu

### Phase 5: Milestone 3 - First Working Tool
**Add first tool to list-tools:**
```nushell
def "main list-tools" [] {
    [
        {
            name: "first_tool"
            description: "Description of what this tool does"
            input_schema: {
                type: "object"
                properties: {
                    input: {
                        type: "string"
                        description: "Input parameter description"
                    }
                }
                required: ["input"]
            }
        }
    ] | to json
}
```

**Implement in call-tool:**
```nushell
match $tool_name {
    "first_tool" => {  # snake_case for tool name
        first-tool-impl ($parsed_args | get input)  # kebab-case for function
    }
    _ => {
        error make {msg: $"Unknown tool: ($tool_name)"}
    }
}

# Implementation function in kebab-case
def first-tool-impl [input: string] {
    # Call API (kebab-case function call)
    let api_result = call-api $input
    
    # Validate response (kebab-case function call)
    let validation = validate-response $api_result
    if not $validation.valid {
        return $validation.error
    }
    
    # Return data (formatting comes later)
    $validation.data | to json
}
```

**Test manually:**
```bash
nu tools/<tool-name>/mod.nu list-tools | from json
nu tools/<tool-name>/mod.nu call-tool first_tool '{"input": "test"}'
```

**Update plan:**
- [ ] ✅ Milestone 3: First working tool

### Phase 6: Milestone 4 - Error Handling
**Add comprehensive error handling:**
```nushell
# kebab-case for function name
def first-tool-impl [input: string] {
    # Validate input
    if ($input | str length) < 2 {
        return "Error: Input must be at least 2 characters"
    }
    
    # Call API with error handling (kebab-case calls)
    let api_result = call-api $input
    let validation = validate-response $api_result
    
    if not $validation.valid {
        return $"Error: ($validation.error)

Please verify:
- Input is correct
- External service is available"
    }
    
    # Success path
    $validation.data | to json
}
```

**Test error scenarios:**
- Invalid input
- API failures
- Missing data
- Malformed responses

**Update plan:**
- [ ] ✅ Milestone 4: Error handling and validation

### Phase 7: Milestone 5 - Additional Tools
**Repeat Milestones 3-4 for each additional tool**

Follow same pattern:
1. Add to list-tools
2. Implement in call-tool
3. Add error handling
4. Test

**Update plan:**
- [ ] ✅ Milestone 5: Additional tools

### Phase 8: Milestone 6 - Formatters
**Create formatters.nu:**
```nushell
# Data formatting and display utilities
# NOTE: Use kebab-case for ALL function names

# Format main output (kebab-case)
export def format-result [data: record, context: record] {
    let lines = [
        $"Result for ($context.input):"
        $"  Field 1: ($data.field1)"
        $"  Field 2: ($data.field2)"
        ""
        $"Source: ($context.source)"
    ]
    
    $lines | str join (char newline)
}

# Format error messages (kebab-case)
export def format-error [operation: string, error: string] {
    $"Error in ($operation): ($error)

Please check your input and try again.
See README.md for more information."
}

# Helper formatters (as needed, kebab-case)
export def format-timestamp [ts: string] {
    # Format timestamp for display
}
```

**Update mod.nu:**
```nushell
use formatters.nu *

# kebab-case for function name
def first-tool-impl [input: string] {
    # ... validation and API call ...
    
    # Format output (kebab-case function call)
    format-result $validation.data { input: $input, source: "API" }
}
```

**Update plan:**
- [ ] ✅ Milestone 6: Formatters and user-friendly output

### Phase 9: Milestone 7 - Documentation
**Create README.md:**
```markdown
# <Tool Name> MCP Tool

## Overview
Brief description of what this tool does and why it's useful.

## Requirements
- External dependencies (APIs, CLI tools)
- Environment variables (if any)
- API keys or credentials (if needed)

## Configuration
### Environment Variables
- `MCP_TOOL_MODE`: Safety mode (readonly/non-destructive/destructive) - default: readonly
- `API_KEY`: Your API key (if required)

## Available Tools

### tool_name
Description of what this tool does.

**Parameters:**
- `param1` (required): Description
- `param2` (optional): Description, defaults to X

**Example:**
\`\`\`json
{
  "param1": "value",
  "param2": "value"
}
\`\`\`

**Returns:**
Description of what this returns.

## Safety and Permissions
If tool has safety modes, document:
- Readonly tools (safe for all operations)
- Non-destructive tools (modify but don't delete)
- Destructive tools (can delete/destroy data)

## Error Handling
Common errors and how to resolve them.

## Development
- Testing commands
- How to contribute
```

**Update plan:**
- [ ] ✅ Milestone 7: Documentation and README

### Phase 10: Milestone 8 - Testing
**Create test cases:**
```bash
# Test discovery
nu tools/<tool-name>/mod.nu list-tools | from json

# Test each tool with valid input
nu tools/<tool-name>/mod.nu call-tool first_tool '{"input": "valid"}'

# Test error cases
nu tools/<tool-name>/mod.nu call-tool first_tool '{"input": ""}'  # Invalid
nu tools/<tool-name>/mod.nu call-tool unknown_tool '{}'  # Unknown tool
nu tools/<tool-name>/mod.nu call-tool first_tool 'invalid json'  # Bad JSON

# Test with actual MCP server
cargo run -- --tools-dir ./tools
```

**Document test results in plan:**
```markdown
## Test Results
- [ ] ✅ Discovery works
- [ ] ✅ Valid inputs return expected output
- [ ] ✅ Invalid inputs return clear errors
- [ ] ✅ API failures handled gracefully
- [ ] ✅ Works with MCP server
```

**Update plan:**
- [ ] ✅ Milestone 8: Testing and edge cases

## Advanced Patterns

### Pattern: CLI Wrapping (Kubernetes, ArgoCD)
When wrapping CLI tools like `kubectl`:

```nushell
# utils.nu
export def run-cli [
    args: list<string>
    --namespace: string = ""
    --context: string = ""
    --output: string = "json"
] {
    mut cmd_args = ["cli-tool"]
    
    # Add context if specified
    if $context != "" {
        $cmd_args = ($cmd_args | append ["--context" $context])
    }
    
    # Add the actual command
    $cmd_args = ($cmd_args | append $args)
    
    # Add namespace
    if $namespace != "" {
        $cmd_args = ($cmd_args | append ["--namespace" $namespace])
    }
    
    # Add output format
    if $output in ["json", "yaml"] {
        $cmd_args = ($cmd_args | append ["--output" $output])
    }
    
    # Execute
    try {
        let kube_args = ($cmd_args | skip 1)
        let result = ^cli-tool ...$kube_args
        
        # Parse based on output format
        if $output == "json" {
            $result | from json
        } else if $output == "yaml" {
            $result | from yaml
        } else {
            $result | str trim
        }
    } catch {
        {
            error: "CommandFailed"
            message: ($in | str trim)
            isError: true
        }
    }
}
```

### Pattern: Environment Configuration
```nushell
# utils.nu
export def get-config [] {
    {
        mode: ($env.MCP_TOOL_MODE? | default "readonly")
        api_key: ($env.API_KEY? | default "")
        timeout: ($env.API_TIMEOUT? | default "30" | into int)
        debug: ($env.DEBUG? | default "false") == "true"
    }
}

export def validate-config [] {
    let config = get-config
    
    if $config.api_key == "" {
        error make {
            msg: "API_KEY environment variable is required"
        }
    }
    
    if $config.mode not-in ["readonly", "non-destructive", "destructive"] {
        print -e $"Warning: Invalid mode '($config.mode)', using 'readonly'"
        return ($config | upsert mode "readonly")
    }
    
    $config
}
```

### Pattern: Response Caching
For expensive operations, consider caching:

```nushell
# utils.nu
const CACHE_DIR = ".cache/tool-name"

export def get-cached [key: string, ttl_seconds: int = 300] {
    let cache_file = $"($CACHE_DIR)/($key).json"
    
    if ($cache_file | path exists) {
        let age = (
            (date now) - (ls $cache_file | get modified | first)
        ) | format duration sec | into int
        
        if $age < $ttl_seconds {
            return (open $cache_file | from json)
        }
    }
    
    null
}

export def set-cached [key: string, data: any] {
    mkdir $CACHE_DIR
    let cache_file = $"($CACHE_DIR)/($key).json"
    $data | to json | save -f $cache_file
}
```

### Pattern: Pagination
For tools that return large lists:

```nushell
# api.nu
export def get-paginated [
    endpoint: string
    limit: int = 50
    offset: int = 0
] {
    let url = $"($endpoint)?limit=($limit)&offset=($offset)"
    
    try {
        let response = http get $url
        {
            success: true
            data: $response.items
            total: $response.total
            limit: $limit
            offset: $offset
            has_more: ($offset + $limit) < $response.total
        }
    } catch { |err|
        {
            success: false
            error: $"Pagination failed: ($err.msg)"
        }
    }
}
```

## Testing Your Tool

### Manual Testing Checklist
- [ ] Tool discovery: `nu tools/<name>/mod.nu list-tools | from json`
- [ ] Tool schema validation: Check all required fields present
- [ ] Happy path: Valid input returns expected output
- [ ] Invalid input: Returns clear error message
- [ ] Missing required params: Returns clear error
- [ ] Unknown tool: Returns "Unknown tool" error
- [ ] Malformed JSON: Returns parse error
- [ ] API/CLI failures: Handled gracefully with user guidance
- [ ] Integration: Works with full MCP server

### Integration Testing
```bash
# Start server with your tool
cargo run -- --tools-dir ./tools

# In another terminal, use MCP client to test
# (This depends on your MCP client setup)
```

### Edge Cases to Test
1. Empty string inputs
2. Very long inputs
3. Special characters in inputs
4. Non-existent resources
5. Network failures (if applicable)
6. Rate limiting (if applicable)
7. Concurrent calls (if stateful)

## Common Pitfalls and Solutions

### Pitfall 1: Not Handling Both String and Record Args
**Problem:** `call-tool` receives string from Rust, record from direct calls
**Solution:** Always check type and handle both
```nushell
let parsed_args = if ($args | describe) == "string" {
    $args | from json
} else {
    $args
}
```

### Pitfall 2: Poor Error Messages
**Problem:** Errors like "Error" or technical stack traces
**Solution:** User-friendly errors with guidance
```nushell
# ❌ Bad
error make {msg: "API call failed"}

# ✅ Good
error make {
    msg: $"Failed to fetch data: ($error_details)

Please check:
- Your API key is set in API_KEY environment variable
- The service is available at ($url)
- Your input '($input)' is valid

See README.md for more information."
}
```

### Pitfall 3: Monolithic mod.nu
**Problem:** All code in one file becomes unmaintainable
**Solution:** Use modular structure with specialized files

### Pitfall 4: Not Validating Inputs
**Problem:** Bad inputs cause cryptic errors deep in execution
**Solution:** Validate early, fail fast with clear messages

### Pitfall 5: Exposing Sensitive Data
**Problem:** Logging or returning API keys, tokens
**Solution:** Mask sensitive data in outputs
```nushell
export def mask-secrets [data: record] {
    if "apiKey" in $data {
        $data | upsert apiKey "***MASKED***"
    } else {
        $data
    }
}
```

### Pitfall 6: No Safety Modes
**Problem:** Destructive operations available by default
**Solution:** Implement safety modes for risky operations

### Pitfall 7: Inconsistent Return Types
**Problem:** Sometimes returns string, sometimes record
**Solution:** Always return consistent format (usually JSON string for MCP)

## Checklist: Pre-Commit Review

Before committing your tool, verify:

### Code Quality
- [ ] Follows modular structure (separate concerns)
- [ ] All exports are intentional (no accidental exports)
- [ ] Private functions don't have `export`
- [ ] **Consistent naming: snake_case for tool names, kebab-case for function names**
- [ ] No hardcoded values (use config/env vars)
- [ ] No sensitive data in code

### Functionality
- [ ] All tools in `list-tools` are implemented
- [ ] All required parameters validated
- [ ] Optional parameters have defaults
- [ ] Error cases handled with user-friendly messages
- [ ] Tested manually with valid inputs
- [ ] Tested manually with invalid inputs
- [ ] Works with MCP server integration

### Documentation
- [ ] README.md created with all sections
- [ ] Implementation plan updated with completed milestones
- [ ] Code comments for complex logic
- [ ] Environment variables documented
- [ ] Example usage provided

### SOLID Principles
- [ ] Each module has single responsibility
- [ ] Easy to add new tools without modifying existing code
- [ ] Consistent interfaces (validation, error handling)
- [ ] No unnecessary exports (interface segregation)
- [ ] Functions depend on data structures, not implementations

### Security
- [ ] No sensitive data exposed in logs/outputs
- [ ] Destructive operations protected by safety modes (if applicable)
- [ ] Input validation prevents injection attacks
- [ ] API keys from environment, not hardcoded

## Final Workflow Summary

1. **Research** → Use Context7 for libraries/APIs
2. **Plan** → Create implementation plan in `docs/implementation-plans/`
3. **Branch** → Create feature branch
4. **Implement** → Follow milestones iteratively:
   - Milestone 1: Structure
   - Milestone 2: API Integration
   - Milestone 3: First Tool
   - Milestone 4: Error Handling
   - Milestone 5: Additional Tools
   - Milestone 6: Formatting
   - Milestone 7: Documentation
   - Milestone 8: Testing
5. **Review** → Use pre-commit checklist
6. **Commit** → Commit to feature branch
7. **Pull Request** → Create PR for review

## Resources

- **Nushell Documentation**: https://www.nushell.sh/book/
- **JSON Schema**: https://json-schema.org/
- **MCP Specification**: https://spec.modelcontextprotocol.io/
- **Existing Tools**: See `tools/` directory for examples
- **Context7**: Use for API/library research

---

**Remember**: Good tools are:
- **Discoverable**: Clear schemas, good descriptions
- **Reliable**: Handle errors gracefully
- **Maintainable**: Modular, well-documented
- **Safe**: Validate inputs, protect operations
- **User-friendly**: Clear errors, helpful messages
- **Correctly named**: `snake_case` for tool names, `kebab-case` for functions
