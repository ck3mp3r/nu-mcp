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
    topiary-nu = {
      url = "github:ck3mp3r/flakes?dir=topiary-nu";
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
          inputs.topiary-nu.overlays.default
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
          buildInputs ? [],
          nativeBuildInputs ? [],
          propagatedBuildInputs ? [],
        }:
          pkgs.stdenv.mkDerivation {
            inherit pname src buildInputs nativeBuildInputs propagatedBuildInputs;
            version = cargoToml.package.version;

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/nushell/mcp-tools/${installPath}
              cp -r * $out/share/nushell/mcp-tools/${installPath}/

              runHook postInstall
            '';

            # Ensure propagated dependencies are properly handled
            passthru = {
              # Make dependencies easily accessible for debugging
              runtimeDependencies = propagatedBuildInputs;
            };

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

        packages = let
          toolPackages = import ./nix/packages.nix {
            inherit pkgs cargoToml mkToolPackage;
          };
        in
          regularPackages
          // archivePackages
          // toolPackages;

        devShells = {
          default = inputs.devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              ./nix/devenv.nix
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
