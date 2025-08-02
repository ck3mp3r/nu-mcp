{
  description = "Rust Nushell MCP Server with Devshell and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    fenix.url = "github:nix-community/fenix";
    nix-utils.url = "github:ck3mp3r/flakes?dir=nix-utils&ref=feat/nix-utils";
  };

  outputs = {
    self,
    nixpkgs,
    nix-utils,
    flake-utils,
    devshell,
    fenix,
    ...
  }: let
    overlays = [
      fenix.overlays.default
      devshell.overlays.default
    ];
    rustMultiarch = nix-utils.lib.rustMultiarch {
      inherit nixpkgs fenix overlays;
      src = ./.;
      cargoToml = ./Cargo.toml;
      cargoLock = {lockFile = ./Cargo.lock;};
      archiveAndHash = true;
    };
  in
    (flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system overlays;};
        fenixToolchain = fenix.packages.${system}.stable.toolchain;
      in {
        devShells.default = pkgs.devshell.mkShell {
          packages = [fenixToolchain];
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
            "${devshell}/extra/git/hooks.nix"
          ];
        };
        formatter = pkgs.alejandra;
        packages.default = rustMultiarch.${system}.default;
      }
    ))
    // {
      packages = rustMultiarch;
      overlays.default = final: prev: {
        nu-mcp = self.packages.${final.system}.default;
      };
    };
}
