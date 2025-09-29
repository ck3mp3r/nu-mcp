#!/usr/bin/env nu

# Ticker tool for nu-mcp - provides stock price information

# Default main command
def main [] {
    help main
}

# List available MCP tools
def "main list-tools" [] {
    [
        {
            name: "get_ticker_price",
            description: "Get the latest price for a stock ticker symbol",
            input_schema: {
                type: "object",
                properties: {
                    symbol: {
                        type: "string",
                        description: "Stock ticker symbol (e.g., AAPL, GOOGL, TSLA)"
                    }
                },
                required: ["symbol"]
            }
        }
    ] | to json
}

# Call a specific tool with arguments
def "main call-tool" [
    tool_name: string  # Name of the tool to call
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

# Get stock price information for a ticker symbol
def get_ticker_price [symbol: string] {
    let ticker = $symbol | str upcase
    
    try {
        # Use a free financial data API (demo endpoint)
        # This is a demonstration - in production you'd use a reliable API like Alpha Vantage, IEX Cloud, etc.
        let url = $"https://api.twelvedata.com/quote?symbol=($ticker)&apikey=demo"
        let response = http get $url
        
        # Check for error in response
        if "status" in $response and $response.status == "error" {
            let message = if "message" in $response { $response.message } else { "Invalid ticker symbol" }
            $"Error: ($message)"
        } else if not ("symbol" in $response) {
            $"Error: No data found for ticker '($ticker)'. Please check the symbol and try again."
        } else {
            # Parse the response
            let price = $response.close | into float
            let prev_close = $response.previous_close | into float
            let change = $price - $prev_close
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
            
            $"Stock Quote for ($ticker):
Company: ($response.name)
Current Price: $($price | math round --precision 2)
Previous Close: $($prev_close | math round --precision 2)
Change: ($change_str) (($change_percent_str))
Open: $($response.open)
High: $($response.high)
Low: $($response.low)
Volume: ($response.volume)
Exchange: ($response.exchange)
Last Updated: ($response.datetime)"
        }
        
    } catch {
        # Fallback to mock data for demonstration
        let mock_data = match $ticker {
            "AAPL" => {
                symbol: "AAPL",
                name: "Apple Inc.",
                price: "178.45",
                prev_close: "176.11", 
                open: "177.30",
                high: "179.20",
                low: "176.85",
                volume: "64,234,567",
                exchange: "NASDAQ",
                datetime: "2025-01-29 16:00:00"
            },
            "GOOGL" => {
                symbol: "GOOGL",
                name: "Alphabet Inc.",
                price: "142.67",
                prev_close: "143.90",
                open: "143.50",
                high: "144.10",
                low: "141.20", 
                volume: "28,123,456",
                exchange: "NASDAQ",
                datetime: "2025-01-29 16:00:00"
            },
            "TSLA" => {
                symbol: "TSLA", 
                name: "Tesla Inc.",
                price: "248.91",
                prev_close: "243.24",
                open: "245.00",
                high: "251.30",
                low: "242.10",
                volume: "95,456,789",
                exchange: "NASDAQ", 
                datetime: "2025-01-29 16:00:00"
            },
            _ => {
                symbol: $ticker,
                name: "Unknown Company",
                price: "0.00",
                prev_close: "0.00",
                open: "N/A",
                high: "N/A", 
                low: "N/A",
                volume: "N/A",
                exchange: "N/A",
                datetime: "N/A"
            }
        }
        
        let price = $mock_data.price | into float
        let prev_close = $mock_data.prev_close | into float
        let change = $price - $prev_close
        let change_percent = if $prev_close > 0 { ($change / $prev_close) * 100 } else { 0 }
        
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
        
        $"Stock Quote for ($ticker): (DEMO DATA)
Company: ($mock_data.name)
Current Price: $($mock_data.price)
Previous Close: $($mock_data.prev_close)
Change: ($change_str) (($change_percent_str))
Open: $($mock_data.open)
High: $($mock_data.high)
Low: $($mock_data.low)
Volume: ($mock_data.volume)
Exchange: ($mock_data.exchange)
Last Updated: ($mock_data.datetime)"
    }
}