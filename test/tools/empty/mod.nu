#!/usr/bin/env nu

# Tool that returns empty tools list

def main [] {
    help main
}

def "main list-tools" [] {
    [] | to json
}

def "main call-tool" [
    tool_name: string
    args: string = "{}"
] {
    error make {msg: $"No tools available"}
}