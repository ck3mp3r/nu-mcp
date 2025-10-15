# Best Practices

## Error Handling and Validation Patterns

Modular tools should implement consistent error handling and validation:

### Input Validation
```nushell
# In mod.nu - validate tool arguments
def "main call-tool" [tool_name: string, args: string = "{}"] {
  let parsed_args = try { $args | from json } catch { 
    return (error make {msg: "Invalid JSON arguments"}) 
  }
  
  # Validate required parameters
  if "symbol" not-in $parsed_args {
    return (error make {msg: "Missing required parameter: symbol"})
  }
}
```

### API Response Validation
```nushell
# In api modules - validate external responses
export def validate_api_response [response: any] {
  if ($response | describe) == "record" and "error" not-in $response {
    { valid: true, data: $response }
  } else {
    { valid: false, error: "Invalid API response" }
  }
}
```

### Error Formatting
```nushell
# In formatter modules - consistent error messages
export def format_error [operation: string, details: string] {
  $"Error in ($operation): ($details). Please check your input and try again."
}
```

## Performance Considerations

### Tool Discovery Performance
- Tool discovery occurs once at server startup
- Large tools directories may increase startup time
- Failed tool modules are logged as warnings but don't stop discovery
- Consider organizing tools into focused directories for better maintainability

### Runtime Performance
- Each tool call spawns a new Nushell process
- Tool modules are not cached between calls
- Heavy computations should be optimized within the tool implementation
- Consider tool design for frequently called operations