# Weather tool for nu-mcp - provides weather information tools
# Uses modular structure with helper modules for better organization

# Import helper modules
use geocoding.nu *
use api.nu *
use formatters.nu *

# Default main command
def main [] {
  help main
}

# List available MCP tools
def "main list-tools" [] {
  [
    {
      name: "get_weather"
      description: "Get current weather for a location"
      input_schema: {
        type: "object"
        properties: {
          location: {
            type: "string"
            description: "City name or location to get weather for"
          }
        }
        required: ["location"]
      }
    }
    {
      name: "get_forecast"
      description: "Get weather forecast for a location with specified number of days"
      input_schema: {
        type: "object"
        properties: {
          location: {
            type: "string"
            description: "City name or location to get forecast for"
          }
          days: {
            type: "integer"
            description: "Number of days for forecast (1-16, default: 5)"
            minimum: 1
            maximum: 16
          }
        }
        required: ["location"]
      }
    }
  ] | to json
}

# Call a specific tool with arguments
def "main call-tool" [
  tool_name: string # Name of the tool to call
  args: string = "{}" # JSON arguments for the tool
] {
  let parsed_args = $args | from json

  match $tool_name {
    "get_weather" => {
      get_weather ($parsed_args | get location)
    }
    "get_forecast" => {
      let location = $parsed_args | get location
      let days = if "days" in $parsed_args { $parsed_args | get days } else { 5 }
      get_forecast $location $days
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}

# Main weather functions using helper modules

# Get weather information for a location using Open-Meteo API
def get_weather [location: string] {
  # Validate location using geocoding module
  let location_result = validate_location $location

  if not $location_result.valid {
    return $location_result.error
  }

  # Get current weather data using API module
  let weather_result = get_current_weather $location_result.latitude $location_result.longitude
  let weather_validation = validate_current_weather_response $weather_result

  if not $weather_validation.valid {
    return $weather_validation.error
  }

  # Format using formatters module
  format_current_weather $location_result.name $location_result.country $weather_validation.data {
    latitude: $location_result.latitude
    longitude: $location_result.longitude
  }
}

# Get weather forecast for a location using Open-Meteo API
def get_forecast [location: string days: int = 5] {
  # Validate location using geocoding module
  let location_result = validate_location $location

  if not $location_result.valid {
    return $location_result.error
  }

  # Get forecast data using API module
  let forecast_result = get_forecast_data $location_result.latitude $location_result.longitude $days
  let forecast_validation = validate_forecast_response $forecast_result

  if not $forecast_validation.valid {
    return $forecast_validation.error
  }

  # Format using formatters module
  format_forecast $location_result.name $location_result.country $forecast_validation.data {
    latitude: $location_result.latitude
    longitude: $location_result.longitude
  } $forecast_validation.requested_days
}
