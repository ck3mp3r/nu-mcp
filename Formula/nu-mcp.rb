class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.6.1"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.6.1/nu-mcp-0.6.1-aarch64-darwin.tgz"
      sha256 "63a2a9217994d0f927a32b2ae30fe2485893358f8e42a7bd807cd23632c3b1c9"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.6.1/nu-mcp-0.6.1-x86_64-linux.tgz"
      sha256 "fa71ad5c1d73b72feff848b93bf401c7e90e48e9023fde5e2eea4338c76f4853"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.6.1/nu-mcp-0.6.1-aarch64-linux.tgz"
      sha256 "827ebcf3d3201cded637d5123764ae9fdeb6cc79f8b2d8b1d723e941a5a96bce"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
