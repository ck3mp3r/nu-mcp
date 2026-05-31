class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.8.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.8.0/nu-mcp-0.8.0-aarch64-darwin.tgz"
      sha256 "53bd78124c9dce506c4c98f8725847bf9811c341395b1de77ee3e4025cbf73c0"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.8.0/nu-mcp-0.8.0-x86_64-linux.tgz"
      sha256 "248a382efb026f9013f2cffbc604fc6fafedccb69af0d7051cfda3b6da14362b"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.8.0/nu-mcp-0.8.0-aarch64-linux.tgz"
      sha256 "5d3afc48d5b2d678d4653820195c8155058eb06160bf3657177f136610d4aeb4"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
