{
  description = "Rust Nushell MCP Server with Devshell and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rustix = {
      url = "github:ck3mp3r/flakes?dir=rustix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    rustix,
    flake-utils,
    devshell,
    fenix,
    ...
  }: let
    overlays = [
      fenix.overlays.default
      devshell.overlays.default
    ];

    systems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    dataDir = ./data;
    installData = builtins.listToAttrs (map (system: {
        name = system;
        value = builtins.fromJSON (builtins.readFile (dataDir + "/${system}.json"));
      })
      systems);
    cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
    cargoLock = {lockFile = ./Cargo.lock;};
    src = ./.;
  in
    flake-utils.lib.eachSystem systems (system: let
      pkgs = import nixpkgs {inherit system overlays;};
    in {
      devShells = {
        ci = pkgs.devshell.mkShell {
          packages = [fenix.packages.${system}.stable.toolchain pkgs.nushell];
        };
        default = pkgs.devshell.mkShell {
          packages = [fenix.packages.${system}.stable.toolchain];
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
            "${devshell}/extra/git/hooks.nix"
          ];
        };
      };
      formatter = pkgs.alejandra;
      packages = rustix.lib.rust.buildPackages {
        inherit
          cargoLock
          cargoToml
          fenix
          installData
          nixpkgs
          overlays
          pkgs
          src
          system
          systems
          ;
        nativeBuildInputs = [pkgs.nushell];
        packageName = "nu-mcp";
        archiveAndHash = true;
      };
    })
    // {
      overlays.default = final: prev: {
        nu-mcp = self.packages.${final.system}.default;
      };
    };
}
