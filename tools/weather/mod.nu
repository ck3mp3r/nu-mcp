# Weather tool for nu-mcp - provides weather information tools

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

# Helper function to get location coordinates
def get_location_coordinates [location: string] {
  let geocode_url = $"https://geocoding-api.open-meteo.com/v1/search?name=($location | url encode)&count=1"
  let geocode_response = http get $geocode_url

  if ($geocode_response.results | length) == 0 {
    null
  } else {
    $geocode_response.results.0
  }
}

# Helper function to convert weather code to description
def weather_code_to_description [code: int] {
  match $code {
    0 => "Clear sky"
    1 => "Mainly clear"
    2 => "Partly cloudy"
    3 => "Overcast"
    45 => "Fog"
    48 => "Depositing rime fog"
    51 => "Light drizzle"
    53 => "Moderate drizzle"
    55 => "Dense drizzle"
    61 => "Slight rain"
    63 => "Moderate rain"
    65 => "Heavy rain"
    71 => "Slight snow"
    73 => "Moderate snow"
    75 => "Heavy snow"
    80 => "Slight rain showers"
    81 => "Moderate rain showers"
    82 => "Violent rain showers"
    95 => "Thunderstorm"
    96 => "Thunderstorm with slight hail"
    99 => "Thunderstorm with heavy hail"
    _ => $"Weather code ($code)"
  }
}

# Helper function to convert wind direction to compass direction
def wind_direction_to_compass [direction] {
  let dir = $direction | into float
  match $dir {
    $d if $d < 22.5 => "N"
    $d if $d < 67.5 => "NE"
    $d if $d < 112.5 => "E"
    $d if $d < 157.5 => "SE"
    $d if $d < 202.5 => "S"
    $d if $d < 247.5 => "SW"
    $d if $d < 292.5 => "W"
    $d if $d < 337.5 => "NW"
    _ => "N"
  }
}

# Get weather information for a location using Open-Meteo API
def get_weather [location: string] {
  let location_data = get_location_coordinates $location

  if $location_data == null {
    $"Error: Location '($location)' not found. Please check the spelling and try again."
  } else {
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
    let condition = weather_code_to_description $weather_code

    # Convert wind direction to compass direction
    let wind_dir = wind_direction_to_compass $wind_direction

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

# Get weather forecast for a location using Open-Meteo API
def get_forecast [location: string days: int = 5] {
  # Validate days parameter
  let forecast_days = if $days < 1 { 5 } else if $days > 16 { 16 } else { $days }

  let location_data = get_location_coordinates $location

  if $location_data == null {
    $"Error: Location '($location)' not found. Please check the spelling and try again."
  } else {
    let lat = $location_data.latitude
    let lon = $location_data.longitude
    let city_name = $location_data.name
    let country = $location_data.country

    # Get forecast data using coordinates
    let weather_url = $"https://api.open-meteo.com/v1/forecast?latitude=($lat)&longitude=($lon)&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_direction_10m_dominant&timezone=auto&forecast_days=($forecast_days)"
    let weather_response = http get $weather_url

    let daily = $weather_response.daily
    let dates = $daily.time
    let weather_codes = $daily.weather_code
    let temp_max = $daily.temperature_2m_max
    let temp_min = $daily.temperature_2m_min
    let precipitation = $daily.precipitation_sum
    let wind_speed = $daily.wind_speed_10m_max
    let wind_direction = $daily.wind_direction_10m_dominant

    mut forecast_lines = [$"($forecast_days)-Day Weather Forecast for ($city_name), ($country):"]

    for i in 0..<($dates | length) {
      let date = $dates | get $i
      let code = $weather_codes | get $i
      let max_temp = $temp_max | get $i
      let min_temp = $temp_min | get $i
      let precip = $precipitation | get $i
      let wind = $wind_speed | get $i
      let wind_dir = $wind_direction | get $i

      # Convert weather code to description
      let condition = weather_code_to_description $code

      # Convert wind direction to compass direction
      let wind_compass = wind_direction_to_compass $wind_dir

      let day_line = $"($date): ($condition), High: ($max_temp)°C, Low: ($min_temp)°C, Rain: ($precip)mm, Wind: ($wind) km/h ($wind_compass)"
      $forecast_lines = ($forecast_lines | append $day_line)
    }

    $forecast_lines = ($forecast_lines | append $"Coordinates: ($lat), ($lon)")
    $forecast_lines = ($forecast_lines | append "Data from: Open-Meteo API")

    $forecast_lines | str join (char newline)
  }
}

