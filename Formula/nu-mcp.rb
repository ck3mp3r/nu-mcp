class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.7.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.7.0/nu-mcp-0.7.0-aarch64-darwin.tgz"
      sha256 "cf3ed5b44112fe1d02ff065572e0eccecaa7af63997e18d4c0657fe3b7b2aeff"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.7.0/nu-mcp-0.7.0-x86_64-linux.tgz"
      sha256 "29fe13c2593a996a32437f9a7e53ddcff5bb44ca89d77192ddb14bb75640d3a9"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.7.0/nu-mcp-0.7.0-aarch64-linux.tgz"
      sha256 "7f58462c509d0b8f849e63f41747cfcc2ecb62543467d39fd30d9b13a67f4fd2"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
