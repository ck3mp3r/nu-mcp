{
  description = "Rust Nushell MCP Server with Devshell and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    fenix.url = "github:nix-community/fenix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    devshell,
    fenix,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [
          fenix.overlays.default
          devshell.overlays.default
        ];
        pkgs = import nixpkgs {inherit system overlays;};

        fenixToolchain = fenix.packages.${system}.stable.toolchain;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = fenixToolchain;
          rustc = fenixToolchain;
          rust-analyzer = fenixToolchain;
        };

        nu-mcp = rustPlatform.buildRustPackage {
          pname = "nu-mcp";
          version = "0.1.0";
          src = ./.;
          cargoLock = {
            lockFile = ./Cargo.lock;
          };
        };
      in {
        devShells.default = pkgs.devshell.mkShell {
          packages = [
            fenixToolchain
          ];
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
            "${devshell}/extra/git/hooks.nix"
          ];
        };

        formatter = pkgs.alejandra;
        packages.default = nu-mcp;
      }
    )
    // {
      overlays.default = final: prev: {
        nu-mcp = self.packages.${final.system}.default;
      };
    };
}
