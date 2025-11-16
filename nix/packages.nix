{
  pkgs,
  cargoToml,
  mkToolPackage,
}: {
  # Individual tool packages
  argocd-mcp-tools = mkToolPackage {
    pname = "argocd-mcp-tools";
    src = ../tools/argocd;
    installPath = "argocd";
    description = "ArgoCD MCP tool for nu-mcp - provides ArgoCD application and resource management via HTTP API";
  };

  weather-mcp-tools = mkToolPackage {
    pname = "weather-mcp-tools";
    src = ../tools/weather;
    installPath = "weather";
    description = "Weather MCP tool for nu-mcp - provides current weather and forecasts using Open-Meteo API";
  };

  finance-mcp-tools = mkToolPackage {
    pname = "finance-mcp-tools";
    src = ../tools/finance;
    installPath = "finance";
    description = "Finance MCP tool for nu-mcp - provides stock prices and financial data using Yahoo Finance API";
  };

  tmux-mcp-tools = mkToolPackage {
    pname = "tmux-mcp-tools";
    src = ../tools/tmux;
    installPath = "tmux";
    description = "Tmux MCP tool for nu-mcp - provides tmux session and pane management with intelligent command execution";
  };

  c67-mcp-tools = mkToolPackage {
    pname = "c67-mcp-tools";
    src = ../tools/c67;
    installPath = "c67";
    description = "Context7 MCP tool for nu-mcp - provides up-to-date library documentation and code examples from Context7";
  };

  # Combined tools package for convenience
  mcp-tools = mkToolPackage {
    pname = "mcp-tools";
    src = ../tools;
    installPath = "";
    description = "Complete MCP tools catalog for nu-mcp - includes argocd, weather, finance, tmux, c67, and other useful tools";
  };
}
