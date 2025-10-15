#!/usr/bin/env nu

# Math tools for testing multiple tools in one script

def main [] {
    help main
}

def "main list-tools" [] {
    [
        {
            name: "add_numbers",
            description: "Add two numbers",
            input_schema: {
                type: "object",
                properties: {
                    a: {
                        type: "number",
                        description: "First number"
                    },
                    b: {
                        type: "number",
                        description: "Second number"
                    }
                },
                required: ["a", "b"]
            }
        },
        {
            name: "multiply_numbers",
            description: "Multiply two numbers",
            input_schema: {
                type: "object",
                properties: {
                    x: {
                        type: "number",
                        description: "First number"
                    },
                    y: {
                        type: "number",
                        description: "Second number"
                    }
                },
                required: ["x", "y"]
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
        "add_numbers" => {
            let a = $parsed_args | get a
            let b = $parsed_args | get b
            let result = $a + $b
            $"Result: ($result)"
        }
        "multiply_numbers" => {
            let x = $parsed_args | get x
            let y = $parsed_args | get y
            let result = $x * $y
            $"Product: ($result)"
        }
        _ => {
            error make {msg: $"Unknown tool: ($tool_name)"}
        }
    }
}