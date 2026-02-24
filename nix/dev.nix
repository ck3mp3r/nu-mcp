# This is a complete shell definition that could be used by itself
# It contains all the development environment configuration
{
  pkgs,
  inputs,
  ...
}: let
  fenix = inputs.fenix.packages.${pkgs.system};
  nuMods = inputs.nu-mods.packages.${pkgs.system}.default;
in
  pkgs.mkShellNoCC {
    name = "nu-mcp-dev";

    buildInputs = [
      fenix.stable.toolchain
      pkgs.nushell
      pkgs.cargo-tarpaulin
      pkgs.topiary
      pkgs.topiary-nu
      pkgs.argocd
      nuMods
      pkgs.tmux
    ];

    env = {
      TOPIARY_CONFIG_FILE = "${pkgs.topiary-nu}/languages.ncl";
      TOPIARY_LANGUAGE_DIR = "${pkgs.topiary-nu}/languages";
      NU_LIB_DIRS = "${nuMods}/share/nushell/modules";
    };

    shellHook = ''
      echo "nu-mcp development shell"
      echo "Rust: $(rustc --version)"
      echo "Nu: $(nu --version)"
      echo ""
      echo "Available commands:"
      echo "  check     - Run cargo check"
      echo "  fmt       - Run cargo fmt"
      echo "  tests     - Run cargo test"
      echo "  clippy    - Run cargo clippy"
      echo "  coverage  - Generate code coverage report"
      echo "  build     - Build release binary"
      echo "  test-tools - Run all tool tests"
      echo ""
      echo "Run 'help' to see all commands"
    '';
  }
