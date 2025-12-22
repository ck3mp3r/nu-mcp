class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.5.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.5.0/nu-mcp-0.5.0-aarch64-darwin.tgz"
      sha256 "de6fe94e465fc5af452017db0144a40542cdf992ebf3ddaf2518a56e1fddfa7f"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.5.0/nu-mcp-0.5.0-x86_64-linux.tgz"
      sha256 "dd8d40e08af304fdf43d8ce4eafea31f78b8b5d70f5312249e2f2b77c5466502"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.5.0/nu-mcp-0.5.0-aarch64-linux.tgz"
      sha256 "d95ab2b517b286f034bcfa05b42b13140f5f19910f9590ce25244a3dd68eb571"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
