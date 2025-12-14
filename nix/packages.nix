{mkToolPackage, ...}: rec {
  # Shared common library for all tools (defined first so other packages can reference it)
  common-mcp-tools = mkToolPackage {
    pname = "common-mcp-tools";
    src = ../tools/_common;
    installPath = "_common";
    description = "Shared library for MCP tools - provides common utilities like TOON encoding, formatters, and helpers";
  };

  # Individual tool packages
  argocd-mcp-tools = mkToolPackage {
    pname = "argocd-mcp-tools";
    src = ../tools/argocd;
    installPath = "argocd";
    description = "ArgoCD MCP tool for nu-mcp - provides ArgoCD application and resource management via HTTP API. Requires argocd CLI to be installed and on PATH.";
    buildInputs = [common-mcp-tools];
  };

  weather-mcp-tools = mkToolPackage {
    pname = "weather-mcp-tools";
    src = ../tools/weather;
    installPath = "weather";
    description = "Weather MCP tool for nu-mcp - provides current weather and forecasts using Open-Meteo API";
    buildInputs = [common-mcp-tools];
  };

  finance-mcp-tools = mkToolPackage {
    pname = "finance-mcp-tools";
    src = ../tools/finance;
    installPath = "finance";
    description = "Finance MCP tool for nu-mcp - provides stock prices and financial data using Yahoo Finance API";
    buildInputs = [common-mcp-tools];
  };

  tmux-mcp-tools = mkToolPackage {
    pname = "tmux-mcp-tools";
    src = ../tools/tmux;
    installPath = "tmux";
    description = "Tmux MCP tool for nu-mcp - provides tmux session and pane management with intelligent command execution";
    buildInputs = [common-mcp-tools];
  };

  c67-mcp-tools = mkToolPackage {
    pname = "c67-mcp-tools";
    src = ../tools/c67;
    installPath = "c67";
    description = "Context7 MCP tool for nu-mcp - provides up-to-date library documentation and code examples from Context7";
    buildInputs = [common-mcp-tools];
  };

  k8s-mcp-tools = mkToolPackage {
    pname = "k8s-mcp-tools";
    src = ../tools/k8s;
    installPath = "k8s";
    description = "Kubernetes MCP tool for nu-mcp - provides 21 kubectl/Helm operations with three-tier safety model";
    buildInputs = [common-mcp-tools];
  };

  c5t-mcp-tools = mkToolPackage {
    pname = "c5t-mcp-tools";
    src = ../tools/c5t;
    installPath = "c5t";
    description = "Context (c5t) MCP tool for nu-mcp - provides context/memory management with todo lists, notes, auto-archive, and full-text search";
    buildInputs = [common-mcp-tools];
  };

  # Combined tools package for convenience
  mcp-tools = mkToolPackage {
    pname = "mcp-tools";
    src = ../tools;
    installPath = "";
    description = "Complete MCP tools catalog for nu-mcp - includes k8s, argocd, weather, finance, tmux, c67, c5t (context), and other useful tools";
  };
}
