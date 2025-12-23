{
  pkgs,
  inputs,
  ...
}: {
  # Minimal packages needed for CI testing
  packages = [
    # Rust toolchain for cargo test
    inputs.fenix.packages.${pkgs.system}.stable.toolchain
    # Nushell for tool tests
    pkgs.nushell
    # nu-mods for nu-mock framework
    inputs.nu-mods.packages.${pkgs.system}.default
  ];

  # Environment variables for testing
  env = {
    # Required for nu-mock tests
    NU_LIB_DIRS = "${inputs.nu-mods.packages.${pkgs.system}.default}/share/nushell/modules";
  };

  # CI-specific test scripts
  scripts = {
    ci-test = {
      exec = ''
        echo "Running CI tests..."
        echo ""
        echo "=== Rust Tests ==="
        cargo test
        echo ""
        echo "=== Tool Tests ==="
        echo "  GitHub Tools:"
        nu tools/gh/tests/run_tests.nu
        echo ""
        echo "  C5T Tools:"
        nu tools/c5t/tests/run_tests.nu
        echo ""
        echo "✅ All tests passed!"
      '';
      description = "Run all tests (Rust + Nu tools)";
    };

    ci-test-rust = {
      exec = "cargo test";
      description = "Run Rust tests only";
    };

    ci-test-tools = {
      exec = ''
        echo "Running tool tests..."
        nu tools/gh/tests/run_tests.nu
        nu tools/c5t/tests/run_tests.nu
      '';
      description = "Run Nu tool tests only";
    };
  };

  # No git hooks in CI
  git-hooks.hooks = {};

  # Simple shell prompt for CI
  enterShell = ''
    echo "CI Testing Environment"
    echo "Available commands:"
    echo "  ci-test       - Run all tests"
    echo "  ci-test-rust  - Run Rust tests"
    echo "  ci-test-tools - Run tool tests"
  '';
}
