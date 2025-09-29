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

# Get weather information for a location using Open-Meteo API
def get_weather [location: string] {
    # First, get coordinates for the location using geocoding API
    let geocode_url = $"https://geocoding-api.open-meteo.com/v1/search?name=($location | url encode)&count=1"
    let geocode_response = http get $geocode_url
    
    if ($geocode_response.results | length) == 0 {
        $"Error: Location '($location)' not found. Please check the spelling and try again."
    } else {
        let location_data = $geocode_response.results.0
        let lat = $location_data.latitude
        let lon = $location_data.longitude
        let city_name = $location_data.name
        let country = $location_data.country
        
        # Get current weather data using coordinates
        let weather_url = $"https://api.open-meteo.com/v1/forecast?latitude=($lat)&longitude=($lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m"
        let weather_response = http get $weather_url
        
        let current = $weather_response.current
        let temp = $current.temperature_2m
        let feels_like = $current.apparent_temperature
        let humidity = $current.relative_humidity_2m
        let precipitation = $current.precipitation
        let wind_speed = $current.wind_speed_10m
        let wind_direction = $current.wind_direction_10m
        let weather_code = $current.weather_code
        
        # Convert weather code to description
        let condition = match $weather_code {
            0 => "Clear sky",
            1 => "Mainly clear",
            2 => "Partly cloudy", 
            3 => "Overcast",
            45 => "Fog",
            48 => "Depositing rime fog",
            51 => "Light drizzle",
            53 => "Moderate drizzle",
            55 => "Dense drizzle",
            61 => "Slight rain",
            63 => "Moderate rain",
            65 => "Heavy rain",
            71 => "Slight snow",
            73 => "Moderate snow",
            75 => "Heavy snow",
            80 => "Slight rain showers",
            81 => "Moderate rain showers",
            82 => "Violent rain showers",
            95 => "Thunderstorm",
            96 => "Thunderstorm with slight hail",
            99 => "Thunderstorm with heavy hail",
            _ => $"Weather code ($weather_code)"
        }
        
        # Convert wind direction to compass direction
        let wind_dir = match $wind_direction {
            $dir if $dir < 22.5 => "N",
            $dir if $dir < 67.5 => "NE", 
            $dir if $dir < 112.5 => "E",
            $dir if $dir < 157.5 => "SE",
            $dir if $dir < 202.5 => "S",
            $dir if $dir < 247.5 => "SW",
            $dir if $dir < 292.5 => "W",
            $dir if $dir < 337.5 => "NW",
            _ => "N"
        }
        
        $"Weather in ($city_name), ($country):
Temperature: ($temp)°C - feels like ($feels_like)°C
Condition: ($condition)
Humidity: ($humidity)%
Precipitation: ($precipitation)mm
Wind: ($wind_speed) km/h ($wind_dir)
Coordinates: ($lat), ($lon)
Data from: Open-Meteo API"
    }
}