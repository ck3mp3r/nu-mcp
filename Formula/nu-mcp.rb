class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.9.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.9.0/nu-mcp-0.9.0-aarch64-darwin.tgz"
      sha256 "d966cd79f9c0572a91def884f2c2206273ce869552acfd2b2ec06db96d1b4c81"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.9.0/nu-mcp-0.9.0-x86_64-linux.tgz"
      sha256 "66fef0c3e6891ee8a4cde0678df80b2db31f58cc5d6f7613780d71f7c98d9e5a"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.9.0/nu-mcp-0.9.0-aarch64-linux.tgz"
      sha256 "6ce17040aafecd3f82236068eb3fccfe9a8582ca2d4f7d876f927aa8de15d5e4"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
