class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.7.1"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.7.1/nu-mcp-0.7.1-aarch64-darwin.tgz"
      sha256 "a909fd1518d3c56174d449dcce6f2794704c8f86df9878cea9f118e34a61a2b1"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.7.1/nu-mcp-0.7.1-x86_64-linux.tgz"
      sha256 "68493e8b92904c7f08673bc499a88617fc91da6cb7a6656006cd8d4181947c41"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.7.1/nu-mcp-0.7.1-aarch64-linux.tgz"
      sha256 "c35328cfbb0c61fffa335db2688f07f6a142be9a41d2c7526b12badea2fa3b56"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
