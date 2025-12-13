class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.4.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.4.0/nu-mcp-0.4.0-aarch64-darwin.tgz"
      sha256 "985e71419089975aa16f76b05418a6b396d553f41e7bbb7f61fe4f5e005eed9f"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.4.0/nu-mcp-0.4.0-x86_64-linux.tgz"
      sha256 "ae7d9fd7dddd4206504d13a6343387e7d02bade8713c580b770f46858997fe1f"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.4.0/nu-mcp-0.4.0-aarch64-linux.tgz"
      sha256 "c75b596cc88702f0909e20411696f51299645c0365291e8c3275b4c5b47c810f"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
