#!/usr/bin/env nu

# Invalid tool for testing error handling

def main [] {
    help main
}

def "main list-tools" [] {
    # Return invalid JSON to test error handling
    "this is not valid json"
}

def "main call-tool" [
    tool_name: string
    args: string = "{}"
] {
    "should not reach here"
}