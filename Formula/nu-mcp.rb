class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.6.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.6.0/nu-mcp-0.6.0-aarch64-darwin.tgz"
      sha256 "70d20b0c3bd994d49afd7bc681ad7736f80dbb0a4d89711db65fcf35324c8ee0"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.6.0/nu-mcp-0.6.0-x86_64-linux.tgz"
      sha256 "5e2b305cc26cbfecf84ed336d00f61a546558bcbca414ecff358189c4c4bdbe6"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.6.0/nu-mcp-0.6.0-aarch64-linux.tgz"
      sha256 "6f3441ea335f6860e7d0807bcbcd584e750a6ff58dd66f7ef557d44e5bdb4068"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
