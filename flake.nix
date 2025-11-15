{
  description = "Rust Nushell MCP Server with Devenv and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rustnix = {
      url = "github:ck3mp3r/flakes?dir=rustnix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-linux"];
      perSystem = {
        config,
        system,
        ...
      }: let
        supportedTargets = ["aarch64-darwin" "aarch64-linux" "x86_64-linux"];
        overlays = [
          inputs.fenix.overlays.default
        ];
        pkgs = import inputs.nixpkgs {inherit system overlays;};

        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        cargoLock = {lockFile = ./Cargo.lock;};

        # Helper function to create tool packages
        mkToolPackage = {
          pname,
          src,
          installPath,
          description,
        }:
          pkgs.stdenv.mkDerivation {
            inherit pname src;
            version = cargoToml.package.version;

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/nushell/mcp-tools/${installPath}
              cp -r * $out/share/nushell/mcp-tools/${installPath}/

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              inherit description;
              license = licenses.mit;
              platforms = platforms.all;
            };
          };

        # Install data for pre-built releases
        installData = {
          aarch64-darwin = builtins.fromJSON (builtins.readFile ./data/aarch64-darwin.json);
          aarch64-linux = builtins.fromJSON (builtins.readFile ./data/aarch64-linux.json);
          x86_64-linux = builtins.fromJSON (builtins.readFile ./data/x86_64-linux.json);
        };

        # Build regular packages (no archives)
        regularPackages = inputs.rustnix.lib.rust.buildTargetOutputs {
          inherit
            cargoToml
            cargoLock
            overlays
            pkgs
            system
            installData
            supportedTargets
            ;
          fenix = inputs.fenix;
          nixpkgs = inputs.nixpkgs;
          src = ./.;
          packageName = "nu-mcp";
          archiveAndHash = false;
          nativeBuildInputs = [pkgs.nushell];
        };

        # Build archive packages (creates archive with system name)
        archivePackages = inputs.rustnix.lib.rust.buildTargetOutputs {
          inherit
            cargoToml
            cargoLock
            overlays
            pkgs
            system
            installData
            supportedTargets
            ;
          fenix = inputs.fenix;
          nixpkgs = inputs.nixpkgs;
          src = ./.;
          packageName = "archive";
          archiveAndHash = true;
          nativeBuildInputs = [pkgs.nushell];
        };
      in {
        apps = {
          default = {
            type = "app";
            program = "${config.packages.default}/bin/nu-mcp";
          };
        };

        packages =
          regularPackages
          // archivePackages
          // {
            # Individual tool packages
            weather-mcp-tools = mkToolPackage {
              pname = "weather-mcp-tools";
              src = ./tools/weather;
              installPath = "weather";
              description = "Weather MCP tool for nu-mcp - provides current weather and forecasts using Open-Meteo API";
            };

            finance-mcp-tools = mkToolPackage {
              pname = "finance-mcp-tools";
              src = ./tools/finance;
              installPath = "finance";
              description = "Finance MCP tool for nu-mcp - provides stock prices and financial data using Yahoo Finance API";
            };

            tmux-mcp-tools = mkToolPackage {
              pname = "tmux-mcp-tools";
              src = ./tools/tmux;
              installPath = "tmux";
              description = "Tmux MCP tool for nu-mcp - provides tmux session and pane management with intelligent command execution";
            };

            c67-mcp-tools = mkToolPackage {
              pname = "c67-mcp-tools";
              src = ./tools/c67;
              installPath = "c67";
              description = "Context7 MCP tool for nu-mcp - provides up-to-date library documentation and code examples from Context7";
            };

            # Combined tools package for convenience
            mcp-tools = mkToolPackage {
              pname = "mcp-tools";
              src = ./tools;
              installPath = "";
              description = "Complete MCP tools catalog for nu-mcp - includes weather, finance, tmux, c67, and other useful tools";
            };
          };

        devShells = {
          default = inputs.devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              ./devenv.nix
            ];
          };
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        overlays.default = final: prev: {
          nu-mcp = self.packages.default;
        };
      };
    };
}
