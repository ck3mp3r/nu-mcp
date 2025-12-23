# Classic Nix shell for CI - just the toolchains needed for testing
{
  pkgs,
  inputs,
  system,
}: let
  fenix = inputs.fenix.packages.${system};

  # Test runner script
  runToolTests = pkgs.writeShellScriptBin "run-tool-tests" ''
    set -e
    echo "Running all nu-mcp tool tests..."
    echo ""

    echo "=== GitHub Tools ==="
    nu tools/gh/tests/run_tests.nu
    echo ""

    echo "=== C5T Tools ==="
    nu tools/c5t/tests/run_tests.nu
    echo ""

    echo "✅ All tool tests passed!"
  '';
in
  pkgs.mkShell {
    name = "nu-mcp-ci";

    buildInputs = [
      # Rust toolchain (stable)
      fenix.stable.toolchain

      # Nushell for tool tests
      pkgs.nushell

      # nu-mods for nu-mock framework
      inputs.nu-mods.packages.${system}.default

      # ArgoCD CLI for argocd tool tests (if needed)
      pkgs.argocd

      # Test runner script
      runToolTests
    ];

    # Environment variables for testing
    NU_LIB_DIRS = "${inputs.nu-mods.packages.${system}.default}/share/nushell/modules";

    shellHook = ''
      echo "CI Testing Environment"
      echo "Rust: $(rustc --version)"
      echo "Nu: $(nu --version)"
      echo ""
      echo "Run all tool tests: run-tool-tests"
    '';
  }
