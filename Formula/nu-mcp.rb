class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.3.8"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.3.8/nu-mcp-0.3.8-aarch64-darwin.tgz"
      sha256 "b109c02ddd219b050d45e9b469962185706f887a4cb44b7288ab8d3b0c04e024"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.3.8/nu-mcp-0.3.8-x86_64-linux.tgz"
      sha256 "51f306ece35e7012ecb7496b268ff5d7e02f8e747052d0bf42633ea98503bb4a"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.3.8/nu-mcp-0.3.8-aarch64-linux.tgz"
      sha256 "9dd75b06f05ee04144666297a2db08f8ba8ae9c86b9a327e988bec565864a0c5"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
