class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.5.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.5.0/nu-mcp-0.5.0-aarch64-darwin.tgz"
      sha256 "4564f10d72ff93c2fddaee2a6697ad6dc2a60398870cf1b2979d261fcc02a051"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.5.0/nu-mcp-0.5.0-x86_64-linux.tgz"
      sha256 "48fde6d75edb5d783c6294098fa33f353ff330b5ba2e44ee53d4c3f897e26358"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.5.0/nu-mcp-0.5.0-aarch64-linux.tgz"
      sha256 "8932b12d440154f180ce19dde72dbba344741921998aa834c4a108fa7f4877e1"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
