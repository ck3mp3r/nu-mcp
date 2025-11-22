# Finance tool for nu-mcp - provides stock price information
# Uses modular structure with helper modules for better organization

# Import helper modules
use yahoo_api.nu *
use utils.nu *
use formatters.nu *

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
  # Get validated stock data using API module
  let stock_result = get_validated_stock_info $symbol

  if not $stock_result.success {
    return (format_stock_error $symbol $stock_result.error)
  }

  # Format using formatters module
  format_stock_quote $stock_result.symbol $stock_result.data
}
