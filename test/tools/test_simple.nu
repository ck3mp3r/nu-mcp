#!/usr/bin/env nu

# Simple test tool for integration testing

def main [] {
    help main
}

def "main list-tools" [] {
    [
        {
            name: "echo_test",
            description: "Simple echo test tool",
            input_schema: {
                type: "object",
                properties: {
                    message: {
                        type: "string",
                        description: "Message to echo"
                    }
                },
                required: ["message"]
            }
        }
    ] | to json
}

def "main call-tool" [
    tool_name: string
    args: string = "{}"
] {
    let parsed_args = $args | from json
    
    match $tool_name {
        "echo_test" => {
            let message = $parsed_args | get message
            $"Echo: ($message)"
        }
        _ => {
            error make {msg: $"Unknown tool: ($tool_name)"}
        }
    }
}