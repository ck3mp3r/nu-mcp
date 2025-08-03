{
  description = "Rust Nushell MCP Server with Devshell and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs";
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
      url = "github:ck3mp3r/flakes?dir=nix-utils&ref=fix/linux-variants";
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
      devShells.default = pkgs.devshell.mkShell {
        packages = [fenix.packages.${system}.stable.toolchain];
        imports = [
          (pkgs.devshell.importTOML ./devshell.toml)
          "${devshell}/extra/git/hooks.nix"
        ];
      };
      formatter = pkgs.alejandra;
      packages = nix-utils.lib.rust.buildPackages {
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
        linuxVariant = "gnu";
        archiveAndHash = true;
      };
    })
    // {
      overlays.default = final: prev: {
        nu-mcp = self.packages.${final.system}.default;
      };
    };
}
