class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.8.1"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.8.1/nu-mcp-0.8.1-aarch64-darwin.tgz"
      sha256 "30ea37ed6b0ced21e634efe8cca56f2f0b3202d2c34d012000b19e2f8ce42e34"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.8.1/nu-mcp-0.8.1-x86_64-linux.tgz"
      sha256 "91e648fe7ea8e6dea9dc056fec7f9ac3fa7e57b4dbbc2f42930b458f236a9252"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.8.1/nu-mcp-0.8.1-aarch64-linux.tgz"
      sha256 "7ff0df03e4192aaa52bc60eb190a84517de2dd6e19f0c5baa7d0cc4d8c2958fd"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
