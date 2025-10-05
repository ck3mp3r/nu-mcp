# Ticker tool for nu-mcp - provides stock price information

# Default main command
def main [] {
  help main
}

# List available MCP tools
def "main list-tools" [] {
  [
    {
      name: "get_ticker_price"
      description: "Get the latest price for a stock ticker symbol"
      input_schema: {
        type: "object"
        properties: {
          symbol: {
            type: "string"
            description: "Stock ticker symbol (e.g., AAPL, GOOGL, TSLA)"
          }
        }
        required: ["symbol"]
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
    "get_ticker_price" => {
      get_ticker_price ($parsed_args | get symbol)
    }
    _ => {
      error make {msg: $"Unknown tool: ($tool_name)"}
    }
  }
}

# Get stock price information for a ticker symbol using Yahoo Finance API
def get_ticker_price [symbol: string] {
  let ticker = $symbol | str upcase

  try {
    # Use Yahoo Finance chart API (no API key required)
    let url = $"https://query1.finance.yahoo.com/v8/finance/chart/($ticker)"
    let response = http get $url

    # Check if we got valid data
    if ($response.chart.result | length) == 0 {
      $"Error: Ticker symbol '($ticker)' not found. Please check the symbol and try again."
    } else {
      let result = $response.chart.result.0
      let meta = $result.meta

      # Extract stock data
      let current_price = $meta.regularMarketPrice
      let prev_close = $meta.previousClose
      let day_high = $meta.regularMarketDayHigh
      let day_low = $meta.regularMarketDayLow
      let volume = $meta.regularMarketVolume
      let company_name = $meta.longName
      let exchange = $meta.fullExchangeName
      let currency = $meta.currency
      let fifty_two_week_high = $meta.fiftyTwoWeekHigh
      let fifty_two_week_low = $meta.fiftyTwoWeekLow

      # Calculate change and percentage
      let change = $current_price - $prev_close
      let change_percent = ($change / $prev_close) * 100

      # Format the change
      let change_str = if $change >= 0 {
        $"+($change | math round --precision 2)"
      } else {
        $"($change | math round --precision 2)"
      }

      let change_percent_str = if $change >= 0 {
        $"+($change_percent | math round --precision 2)%"
      } else {
        $"($change_percent | math round --precision 2)%"
      }

      # Format volume
      let volume_str = if $volume > 1000000 {
        $"($volume / 1000000 | math round --precision 1)M"
      } else if $volume > 1000 {
        $"($volume / 1000 | math round --precision 1)K"
      } else {
        $"($volume)"
      }

      $"Stock Quote for ($ticker):
Company: ($company_name)
Current Price: ($currency) ($current_price | math round --precision 2)
Previous Close: ($currency) ($prev_close | math round --precision 2)
Change: ($change_str) (($change_percent_str))
Day Range: ($currency) ($day_low) - ($currency) ($day_high)
52-Week Range: ($currency) ($fifty_two_week_low) - ($currency) ($fifty_two_week_high)
Volume: ($volume_str)
Exchange: ($exchange)
Data from: Yahoo Finance API"
    }
  } catch {
    $"Error: Could not retrieve data for ticker '($ticker)'. Please check the symbol and try again."
  }
}

