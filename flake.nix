{
  description = "Rust Nushell MCP Server with Devshell and Fenix";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rustnix = {
      url = "github:ck3mp3r/flakes/fix-cross-compilation?dir=rustnix";
      inputs.nixpkgs.follows = "nixpkgs";
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
          inputs.devshell.overlays.default
        ];
        pkgs = import inputs.nixpkgs {inherit system overlays;};

        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        cargoLock = {lockFile = ./Cargo.lock;};

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
            mcp-example-tools = let
              cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
            in
              pkgs.stdenv.mkDerivation {
                pname = "example-tools";
                version = cargoToml.package.version;
                src = ./tools;

                dontBuild = true;
                dontConfigure = true;

                installPhase = ''
                  runHook preInstall

                  mkdir -p $out/share/nushell/mcp-tools/examples
                  cp -r * $out/share/nushell/mcp-tools/examples/

                  runHook postInstall
                '';

                meta = with pkgs.lib; {
                  description = "Example Nushell tools collection";
                  license = licenses.mit;
                  platforms = platforms.all;
                };
              };
          };

        devShells = {
          default = pkgs.devshell.mkShell {
            packages = [inputs.fenix.packages.${system}.stable.toolchain];
            imports = [
              (pkgs.devshell.importTOML ./devshell.toml)
              "${inputs.devshell}/extra/git/hooks.nix"
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
