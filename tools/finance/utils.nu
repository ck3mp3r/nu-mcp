# Financial calculation utilities and helper functions

# Calculate price change and percentage from current and previous prices
export def calculate_price_change [current: float, previous: float] {
  let change = $current - $previous
  let change_percent = if $previous != 0 { ($change / $previous) * 100 } else { 0 }
  
  {
    change: $change
    change_percent: $change_percent
    is_positive: ($change >= 0)
  }
}

# Format price change with appropriate sign
export def format_price_change [change: float, precision: int = 2] {
  if $change >= 0 {
    $"+($change | math round --precision $precision)"
  } else {
    $"($change | math round --precision $precision)"
  }
}

# Format percentage change with appropriate sign and % symbol
export def format_percentage_change [change_percent: float, precision: int = 2] {
  if $change_percent >= 0 {
    $"+($change_percent | math round --precision $precision)%"
  } else {
    $"($change_percent | math round --precision $precision)%"
  }
}

# Format volume with appropriate scale (K, M, B)
export def format_volume [volume: int] {
  if $volume > 1000000000 {
    $"($volume / 1000000000 | math round --precision 1)B"
  } else if $volume > 1000000 {
    $"($volume / 1000000 | math round --precision 1)M"
  } else if $volume > 1000 {
    $"($volume / 1000 | math round --precision 1)K"
  } else {
    $"($volume)"
  }
}

# Format currency amount with specified precision
export def format_currency [amount: float, currency: string = "USD", precision: int = 2] {
  $"($currency) ($amount | math round --precision $precision)"
}

# Format price range (low - high)
export def format_price_range [low: float, high: float, currency: string = "USD", precision: int = 2] {
  let low_formatted = format_currency $low $currency $precision
  let high_formatted = format_currency $high $currency $precision
  $"($low_formatted) - ($high_formatted)"
}

# Calculate market cap if shares outstanding is available
export def calculate_market_cap [price: float, shares_outstanding: int] {
  $price * $shares_outstanding
}

# Determine market trend based on price change
export def get_market_trend [change_percent: float] {
  if $change_percent > 2.0 {
    {
      trend: "strong_up"
      description: "Strong upward movement"
      emoji: "📈"
    }
  } else if $change_percent > 0.5 {
    {
      trend: "up"
      description: "Upward movement"
      emoji: "↗️"
    }
  } else if $change_percent > -0.5 {
    {
      trend: "flat"
      description: "Relatively flat"
      emoji: "➡️"
    }
  } else if $change_percent > -2.0 {
    {
      trend: "down"
      description: "Downward movement"
      emoji: "↘️"
    }
  } else {
    {
      trend: "strong_down"
      description: "Strong downward movement"
      emoji: "📉"
    }
  }
}

# Validate that required numeric fields are present and valid
export def validate_numeric_data [data: record, required_fields: list] {
  let missing_fields = $required_fields | where { |field| 
    $field not-in $data or ($data | get $field | describe) != "float"
  }
  
  if ($missing_fields | length) > 0 {
    {
      valid: false
      error: $"Missing or invalid numeric fields: ($missing_fields | str join ', ')"
    }
  } else {
    {
      valid: true
    }
  }
}