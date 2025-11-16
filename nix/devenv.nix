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
    rustfmt = {
      enable = true;
      packageOverrides.rustfmt = inputs.fenix.packages.${pkgs.system}.stable.rustfmt;
    };
    clippy = {
      enable = true;
      packageOverrides.clippy = inputs.fenix.packages.${pkgs.system}.stable.clippy;
    };
    # Custom pre-push hook to run tests
    test-on-push = {
      enable = true;
      name = "Run tests";
      entry = "cargo test";
      language = "system";
      stages = ["pre-push"];
      pass_filenames = false;
    };
  };

  enterShell = let
    scriptLines =
      lib.mapAttrsToList (
        name: script: "printf '  %-10s  %s\\n' '${name}' '${script.description}'"
      )
      config.scripts;
  in ''
    echo
    echo "Helper scripts you can run to make your development richer:"
    echo ""
    ${lib.concatStringsSep "\n" scriptLines}
    echo
  '';
}
