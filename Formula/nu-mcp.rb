class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.10.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.10.0/nu-mcp-0.10.0-aarch64-darwin.tgz"
      sha256 "a5bdc2f57384e8463b4d29b12b113627f6a9d80a9e94e1e98008c29c15e88c12"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.10.0/nu-mcp-0.10.0-x86_64-linux.tgz"
      sha256 "8a44cb3afe5a46c4158d4807b3ee10c5fa3b4469f50c6a5afcaa0765c73445e4"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.10.0/nu-mcp-0.10.0-aarch64-linux.tgz"
      sha256 "1b0fd678af0528c095e52bc7985ad4ce76edea1b1515a0eb7fa61afb9f141c64"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
