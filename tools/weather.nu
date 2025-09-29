#!/usr/bin/env nu

# Weather tool for nu-mcp - provides weather information tools

# Default main command
def main [] {
    help main
}

# List available MCP tools
def "main list-tools" [] {
    [
        {
            name: "get_weather",
            description: "Get current weather for a location",
            input_schema: {
                type: "object",
                properties: {
                    location: {
                        type: "string",
                        description: "City name or location to get weather for"
                    }
                },
                required: ["location"]
            }
        }
    ] | to json
}

# Call a specific tool with arguments
def "main call-tool" [
    tool_name: string  # Name of the tool to call
    args: string = "{}" # JSON arguments for the tool
] {
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

# Get weather information for a location
def get_weather [location: string] {
    # Mock weather data for now - in real implementation could call weather API
    let weather_data = {
        location: $location,
        temperature: "22°C",
        condition: "Partly cloudy", 
        humidity: "65%",
        wind: "8 km/h NW"
    }
    
    $"Weather in ($weather_data.location):
Temperature: ($weather_data.temperature)
Condition: ($weather_data.condition)
Humidity: ($weather_data.humidity)
Wind: ($weather_data.wind)"
}