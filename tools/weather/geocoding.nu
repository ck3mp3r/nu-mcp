# Geocoding functionality for weather tool
# Handles location resolution and coordinate lookup

# Get location coordinates from a location name
export def get_coordinates [location: string] {
  let geocode_url = $"https://geocoding-api.open-meteo.com/v1/search?name=($location | url encode)&count=1"

  try {
    let geocode_response = http get $geocode_url

    if ($geocode_response.results | length) == 0 {
      null
    } else {
      $geocode_response.results.0
    }
  } catch {
    null
  }
}

# Validate that a location exists and return formatted location info
export def validate_location [location: string] {
  let location_data = get_coordinates $location

  if $location_data == null {
    {
      valid: false
      error: $"Location '($location)' not found. Please check the spelling and try again."
    }
  } else {
    {
      valid: true
      latitude: $location_data.latitude
      longitude: $location_data.longitude
      name: $location_data.name
      country: $location_data.country
      admin1: ($location_data.admin1? | default "")
    }
  }
}

# Format a location for display
export def format_location [location_info: record] {
  if $location_info.admin1 != "" {
    $"($location_info.name), ($location_info.admin1), ($location_info.country)"
  } else {
    $"($location_info.name), ($location_info.country)"
  }
}
