{
  nixpkgs,
  fenix,
  overlays ? [],
  pname,
  version,
  src,
  cargoLock,
  extraArgs ? {},
}: let
  systems = [
    "aarch64-darwin"
    "x86_64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  mkRustPkg = {
    buildSystem,
    targetSystem,
  }: let
    pkgs = import nixpkgs {
      system = buildSystem;
      overlays = overlays;
      crossSystem =
        if buildSystem != targetSystem
        then {config = targetSystem;}
        else null;
    };
    fenixToolchain = fenix.packages.${targetSystem}.stable.toolchain;
    rustPlatform = pkgs.makeRustPlatform {
      cargo = fenixToolchain;
      rustc = fenixToolchain;
      rust-analyzer = fenixToolchain;
    };
  in
    rustPlatform.buildRustPackage ({
        inherit pname version src cargoLock;
      }
      // extraArgs);

  # For each host, expose default (native) and all cross builds
  perHost = host: let
    native = mkRustPkg {
      buildSystem = host;
      targetSystem = host;
    };
    cross = builtins.listToAttrs (
      builtins.filter (x: x != null) (
        map (
          target:
            if target != host
            then {
              name = target;
              value = mkRustPkg {
                buildSystem = host;
                targetSystem = target;
              };
            }
            else null
        )
        systems
      )
    );
  in
    {default = native;} // cross;
in
  builtins.listToAttrs (map (host: {
      name = host;
      value = perHost host;
    })
    systems)
