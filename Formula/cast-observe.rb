class CastObserve < Formula
  desc "Session-level observability for Claude Code"
  homepage "https://github.com/ek33450505/cast-observe"
  url "https://github.com/ek33450505/cast-observe/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "aef7db76b33049b6eac2dcf80d502512eb15f51e5f0e402611d0630ac8d2dd82"  # update after tagging v0.2.1
  license "MIT"
  version "0.2.1"

  depends_on "python3" => :recommended

  def install
    libexec.install Dir["scripts/*"]
    libexec.install Dir["config/*"]
    libexec.install "settings.json"
    (libexec/"VERSION").write(File.read("VERSION"))
    prefix.install "VERSION"

    inreplace "bin/cast-observe",
              'OBSERVE_SCRIPTS_DIR=""',
              "OBSERVE_SCRIPTS_DIR=\"#{libexec}\""

    inreplace "bin/cast-observe",
              /CO_VERSION="\$\(cat.*\|\| echo "unknown"\)"/,
              "CO_VERSION=\"#{version}\""

    bin.install "bin/cast-observe"
  end

  def caveats
    <<~EOS
      Run one-time setup to wire hooks and initialize the database:
        cast-observe install

      This takes under 30 seconds. Then start a Claude Code session
      and run `cast-observe status` to see data flowing in.
    EOS
  end

  test do
    system "#{bin}/cast-observe", "--version"
  end
end
