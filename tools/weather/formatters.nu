# Weather data formatting and conversion utilities

# Convert weather code to human-readable description
export def weather_code_to_description [code: int] {
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

# Convert wind direction in degrees to compass direction
export def wind_direction_to_compass [direction] {
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

# Format temperature with unit
export def format_temperature [temp: float, unit: string = "°C"] {
  $"($temp)($unit)"
}

# Format current weather data into readable text
export def format_current_weather [
  location_name: string
  country: string
  weather_data: record
  coordinates: record
] {
  let temp = $weather_data.temperature_2m
  let feels_like = $weather_data.apparent_temperature
  let humidity = $weather_data.relative_humidity_2m
  let precipitation = $weather_data.precipitation
  let wind_speed = $weather_data.wind_speed_10m
  let wind_direction = $weather_data.wind_direction_10m
  let weather_code = $weather_data.weather_code

  # Convert data using formatters
  let condition = weather_code_to_description $weather_code
  let wind_dir = wind_direction_to_compass $wind_direction

  $"Weather in ($location_name), ($country):
Temperature: (format_temperature $temp) - feels like (format_temperature $feels_like)
Condition: ($condition)
Humidity: ($humidity)%
Precipitation: ($precipitation)mm
Wind: ($wind_speed) km/h ($wind_dir)
Coordinates: ($coordinates.latitude), ($coordinates.longitude)
Data from: Open-Meteo API"
}

# Format forecast data into readable text  
export def format_forecast [
  location_name: string
  country: string
  forecast_data: record
  coordinates: record
  days: int
] {
  let daily = $forecast_data.daily
  let dates = $daily.time
  let weather_codes = $daily.weather_code
  let temp_max = $daily.temperature_2m_max
  let temp_min = $daily.temperature_2m_min
  let precipitation = $daily.precipitation_sum
  let wind_speed = $daily.wind_speed_10m_max
  let wind_direction = $daily.wind_direction_10m_dominant

  mut forecast_lines = [$"($days)-Day Weather Forecast for ($location_name), ($country):"]

  for i in 0..<($dates | length) {
    let date = $dates | get $i
    let code = $weather_codes | get $i
    let max_temp = $temp_max | get $i
    let min_temp = $temp_min | get $i
    let precip = $precipitation | get $i
    let wind = $wind_speed | get $i
    let wind_dir = $wind_direction | get $i

    # Convert data using formatters
    let condition = weather_code_to_description $code
    let wind_compass = wind_direction_to_compass $wind_dir

    let day_line = $"($date): ($condition), High: (format_temperature $max_temp), Low: (format_temperature $min_temp), Rain: ($precip)mm, Wind: ($wind) km/h ($wind_compass)"
    $forecast_lines = ($forecast_lines | append $day_line)
  }

  $forecast_lines = ($forecast_lines | append $"Coordinates: ($coordinates.latitude), ($coordinates.longitude)")
  $forecast_lines = ($forecast_lines | append "Data from: Open-Meteo API")

  $forecast_lines | str join (char newline)
}