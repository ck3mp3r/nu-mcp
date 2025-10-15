# Weather API interaction module
# Handles all Open-Meteo API calls and data retrieval

# Get current weather data from Open-Meteo API
export def get_current_weather [latitude: float, longitude: float] {
  let weather_url = $"https://api.open-meteo.com/v1/forecast?latitude=($latitude)&longitude=($longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m"
  
  try {
    let weather_response = http get $weather_url
    {
      success: true
      data: $weather_response.current
    }
  } catch { |err|
    {
      success: false
      error: $"Failed to fetch current weather data: ($err.msg)"
    }
  }
}

# Get weather forecast data from Open-Meteo API
export def get_forecast_data [latitude: float, longitude: float, days: int = 5] {
  # Validate and clamp days parameter
  let forecast_days = if $days < 1 { 5 } else if $days > 16 { 16 } else { $days }
  
  let weather_url = $"https://api.open-meteo.com/v1/forecast?latitude=($latitude)&longitude=($longitude)&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_direction_10m_dominant&timezone=auto&forecast_days=($forecast_days)"
  
  try {
    let weather_response = http get $weather_url
    {
      success: true
      data: $weather_response
      requested_days: $forecast_days
    }
  } catch { |err|
    {
      success: false
      error: $"Failed to fetch forecast data: ($err.msg)"
    }
  }
}

# Validate API response structure for current weather
export def validate_current_weather_response [response: record] {
  if $response.success != true {
    return {
      valid: false
      error: $response.error
    }
  }
  
  let required_fields = [
    "temperature_2m"
    "relative_humidity_2m" 
    "apparent_temperature"
    "precipitation"
    "weather_code"
    "wind_speed_10m"
    "wind_direction_10m"
  ]
  
  let data = $response.data
  let missing_fields = $required_fields | where { |field| $field not-in $data }
  
  if ($missing_fields | length) > 0 {
    {
      valid: false
      error: $"Missing required fields in API response: ($missing_fields | str join ', ')"
    }
  } else {
    {
      valid: true
      data: $data
    }
  }
}

# Validate API response structure for forecast data
export def validate_forecast_response [response: record] {
  if $response.success != true {
    return {
      valid: false
      error: $response.error
    }
  }
  
  let data = $response.data
  
  if "daily" not-in $data {
    return {
      valid: false
      error: "Missing 'daily' section in forecast response"
    }
  }
  
  let daily = $data.daily
  let required_fields = [
    "time"
    "weather_code"
    "temperature_2m_max"
    "temperature_2m_min"
    "precipitation_sum"
    "wind_speed_10m_max"
    "wind_direction_10m_dominant"
  ]
  
  let missing_fields = $required_fields | where { |field| $field not-in $daily }
  
  if ($missing_fields | length) > 0 {
    {
      valid: false
      error: $"Missing required fields in forecast response: ($missing_fields | str join ', ')"
    }
  } else {
    {
      valid: true
      data: $data
      requested_days: $response.requested_days
    }
  }
}