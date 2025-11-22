# Yahoo Finance API interaction module
# Handles stock data retrieval and response validation

# Validate and normalize ticker symbol
export def normalize_symbol [symbol: string] {
  let ticker = $symbol | str trim | str upcase

  if ($ticker | str length) == 0 {
    {
      valid: false
      error: "Ticker symbol cannot be empty"
    }
  } else {
    {
      valid: true
      symbol: $ticker
    }
  }
}

# Get stock data from Yahoo Finance API
export def get_stock_data [symbol: string] {
  let symbol_check = normalize_symbol $symbol

  if not $symbol_check.valid {
    return {
      success: false
      error: $symbol_check.error
    }
  }

  let ticker = $symbol_check.symbol

  try {
    # Use Yahoo Finance chart API (no API key required)
    let url = $"https://query1.finance.yahoo.com/v8/finance/chart/($ticker)"
    let response = http get $url

    # Check if we got valid data
    if ($response.chart.result | length) == 0 {
      {
        success: false
        error: $"Ticker symbol '($ticker)' not found. Please check the symbol and try again."
      }
    } else {
      {
        success: true
        data: $response.chart.result.0
        symbol: $ticker
      }
    }
  } catch {|err|
    {
      success: false
      error: $"Could not retrieve data for ticker '($ticker)': ($err.msg)"
    }
  }
}

# Extract and validate stock metadata from API response
export def extract_stock_metadata [api_response: record] {
  if not $api_response.success {
    return {
      valid: false
      error: $api_response.error
    }
  }

  let result = $api_response.data

  if "meta" not-in $result {
    return {
      valid: false
      error: "Missing metadata in API response"
    }
  }

  let meta = $result.meta

  # Required fields for stock quote
  let required_fields = [
    "regularMarketPrice"
    "previousClose"
    "regularMarketDayHigh"
    "regularMarketDayLow"
    "regularMarketVolume"
    "currency"
  ]

  let missing_fields = $required_fields | where {|field| $field not-in $meta }

  if ($missing_fields | length) > 0 {
    {
      valid: false
      error: $"Missing required fields in API response: ($missing_fields | str join ', ')"
    }
  } else {
    {
      valid: true
      metadata: $meta
      symbol: $api_response.symbol
    }
  }
}

# Get comprehensive stock information with validation
export def get_validated_stock_info [symbol: string] {
  let api_result = get_stock_data $symbol
  let validation_result = extract_stock_metadata $api_result

  if not $validation_result.valid {
    {
      success: false
      error: $validation_result.error
    }
  } else {
    {
      success: true
      symbol: $validation_result.symbol
      data: $validation_result.metadata
    }
  }
}
