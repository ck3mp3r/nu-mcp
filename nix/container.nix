{
  pkgs,
  cargoToml,
  defaultPackage,
}:
# Container image - build on Linux systems only
# Cross-compilation from Darwin is deferred to CI
pkgs.dockerTools.buildLayeredImage {
  name = "nu-mcp";
  tag = cargoToml.package.version;

  # Closure contents - no base image, just what we need
  contents = [
    defaultPackage # nu-mcp binary
    pkgs.nushell # nu-mcp executes nushell commands at runtime
    pkgs.cacert # CA certificates for HTTPS
  ];

  # Setup /data directory and create non-root user
  extraCommands = ''
    mkdir -p data
    chmod 777 data  # World-writable so nu-mcp user can write when volume is mounted

    # Create /etc for passwd/group files
    mkdir -p etc

    # Create nu-mcp user (UID 1000) and group (GID 1000)
    echo "nu-mcp:x:1000:1000:nu-mcp user:/data:/bin/noshell" > etc/passwd
    echo "nu-mcp:x:1000:" > etc/group
  '';

  config = {
    Cmd = ["/bin/nu-mcp"];
    User = "nu-mcp";
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZ=UTC"
    ];
    WorkingDir = "/data";
  };
}
