# Financial data formatting and display utilities

# Import utility functions
use utils.nu *

# Format a complete stock quote for display
export def format_stock_quote [symbol: string stock_data: record] {
  # Extract data with safe defaults
  let current_price = $stock_data.regularMarketPrice
  let prev_close = $stock_data.previousClose
  let day_high = $stock_data.regularMarketDayHigh
  let day_low = $stock_data.regularMarketDayLow
  let volume = $stock_data.regularMarketVolume
  let currency = $stock_data.currency

  # Optional fields with fallbacks
  let company_name = $stock_data.longName? | default $symbol
  let exchange = $stock_data.fullExchangeName? | default "N/A"
  let fifty_two_week_high = $stock_data.fiftyTwoWeekHigh? | default 0
  let fifty_two_week_low = $stock_data.fiftyTwoWeekLow? | default 0

  # Calculate price changes using utils
  let price_change = calculate_price_change $current_price $prev_close

  # Format all the values
  let current_price_str = format_currency $current_price $currency
  let prev_close_str = format_currency $prev_close $currency
  let change_str = format_price_change $price_change.change
  let change_percent_str = format_percentage_change $price_change.change_percent
  let day_range_str = format_price_range $day_low $day_high $currency
  let volume_str = format_volume $volume

  # Format 52-week range if available
  let fifty_two_week_range_str = if $fifty_two_week_high > 0 and $fifty_two_week_low > 0 {
    format_price_range $fifty_two_week_low $fifty_two_week_high $currency
  } else {
    "N/A"
  }

  # Get market trend for additional context
  let trend = get_market_trend $price_change.change_percent

  $"Stock Quote for ($symbol):
Company: ($company_name)
Current Price: ($current_price_str)
Previous Close: ($prev_close_str)
Change: ($change_str) (($change_percent_str)) ($trend.emoji)
Day Range: ($day_range_str)
52-Week Range: ($fifty_two_week_range_str)
Volume: ($volume_str)
Exchange: ($exchange)
Trend: ($trend.description)
Data from: Yahoo Finance API"
}

# Format a minimal stock quote (just price and change)
export def format_minimal_quote [symbol: string stock_data: record] {
  let current_price = $stock_data.regularMarketPrice
  let prev_close = $stock_data.previousClose
  let currency = $stock_data.currency

  let price_change = calculate_price_change $current_price $prev_close
  let current_price_str = format_currency $current_price $currency
  let change_str = format_price_change $price_change.change
  let change_percent_str = format_percentage_change $price_change.change_percent

  $"($symbol): ($current_price_str) ($change_str) (($change_percent_str))"
}

# Format stock data as a table row (for multiple stocks)
export def format_stock_table_row [symbol: string stock_data: record] {
  let current_price = $stock_data.regularMarketPrice
  let prev_close = $stock_data.previousClose
  let volume = $stock_data.regularMarketVolume
  let currency = $stock_data.currency

  let price_change = calculate_price_change $current_price $prev_close
  let trend = get_market_trend $price_change.change_percent

  {
    Symbol: $symbol
    Price: (format_currency $current_price $currency)
    Change: (format_price_change $price_change.change)
    "Change %": (format_percentage_change $price_change.change_percent)
    Volume: (format_volume $volume)
    Trend: $trend.emoji
  }
}

# Format error message for stock lookup failures
export def format_stock_error [symbol: string error_msg: string] {
  $"❌ Error retrieving stock data for ($symbol):($error_msg)

Please verify:
• The ticker symbol is correct
• The market is open or recently closed
• You have an internet connection
• The stock is publicly traded"
}

# Format stock data for JSON output
export def format_stock_json [symbol: string stock_data: record] {
  let current_price = $stock_data.regularMarketPrice
  let prev_close = $stock_data.previousClose
  let price_change = calculate_price_change $current_price $prev_close
  let trend = get_market_trend $price_change.change_percent

  {
    symbol: $symbol
    price: $current_price
    currency: $stock_data.currency
    change: $price_change.change
    changePercent: $price_change.change_percent
    previousClose: $prev_close
    dayHigh: $stock_data.regularMarketDayHigh
    dayLow: $stock_data.regularMarketDayLow
    volume: $stock_data.regularMarketVolume
    trend: $trend.trend
    trendDescription: $trend.description
    companyName: ($stock_data.longName? | default $symbol)
    exchange: ($stock_data.fullExchangeName? | default "")
    timestamp: (date now | format date '%Y-%m-%d %H:%M:%S')
  } | to json
}
