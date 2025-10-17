{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  packages = [
    inputs.fenix.packages.${pkgs.system}.stable.toolchain
    pkgs.cargo-tarpaulin
  ];

  scripts = {
    check = {
      exec = "cargo check";
      description = "Run cargo check";
    };
    fmt = {
      exec = "cargo fmt";
      description = "Run cargo fmt";
    };
    tests = {
      exec = "cargo test";
      description = "Run cargo test";
    };
    clippy = {
      exec = "cargo clippy $@";
      description = "Run cargo clippy";
    };
    coverage = {
      exec = "cargo tarpaulin --out Html";
      description = "Generate code coverage report";
    };
    build = {
      exec = "cargo build --release";
      description = "Build release binary";
    };
  };

  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
  };

  enterShell = ''
    echo
    echo "Helper scripts you can run to make your development richer:"
    echo ""
    ${pkgs.gnused}/bin/sed -e 's| |••|g' -e 's|=| |' <<EOF | ${pkgs.util-linuxMinimal}/bin/column -t | ${pkgs.gnused}/bin/sed -e 's|^|* |' -e 's|••| |g'
    ${lib.generators.toKeyValue {} (lib.mapAttrs (name: value: value.description) config.scripts)}
    EOF
    echo
  '';
}
