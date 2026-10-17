class NuMcp < Formula
  desc "nu-mcp - Model Context Protocol (MCP) Server for Nushell"
  homepage "https://github.com/ck3mp3r/nu-mcp"
  version "0.9.0"

  depends_on "nushell"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.9.0/nu-mcp-0.9.0-aarch64-darwin.tgz"
      sha256 "5c7a450efd5369a196519038fed55bd0bafe055ea67740cbebf5d5730b8961b5"
    else
      odie "Intel Macs are no longer supported. Please use an Apple Silicon Mac."
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.9.0/nu-mcp-0.9.0-x86_64-linux.tgz"
      sha256 "fec379dcb35396cc4a82f353b356fb24b4ed7a928601de7ef10821f04c39c080"
    elsif Hardware::CPU.arm?
      url "https://github.com/ck3mp3r/nu-mcp/releases/download/v0.9.0/nu-mcp-0.9.0-aarch64-linux.tgz"
      sha256 "dd433e960ddc197dc844a7e9989116c53d9fe38bd20949c756264730082d1965"
    end
  end

  def install
    bin.install "nu-mcp"
  end
end
