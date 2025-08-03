{
  description = "Rust Nushell MCP Server with Devshell and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-utils = {
      url = "github:ck3mp3r/flakes?dir=nix-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      # "aarch64-linux"
      "x86_64-linux"
    ];

    rustMultiarch = nix-utils.lib.rustMultiarch {
      inherit nixpkgs fenix overlays systems;
      src = ./.;
      cargoToml = ./Cargo.toml;
      cargoLock = {lockFile = ./Cargo.lock;};
      archiveAndHash = true;
    };
  in
    (flake-utils.lib.eachSystem systems (
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
