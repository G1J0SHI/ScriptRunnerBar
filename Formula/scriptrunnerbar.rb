# Builds ScriptRunnerBar from source on the user's Mac.
class Scriptrunnerbar < Formula
  desc "Run any script, anytime, with just a click"
  homepage "https://github.com/G1J0SHI/ScriptRunnerBar"
  url "https://github.com/G1J0SHI/ScriptRunnerBar/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "9396fa261586bc05983dc296f196da0dbd8458059f150f8777416c9279e49158"
  license "MIT"
  head "https://github.com/G1J0SHI/ScriptRunnerBar.git", branch: "main"

  depends_on macos: :sequoia

  def install
    # SwiftPM's sandbox can't nest inside Homebrew's.
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    system "./Scripts/install.sh", "--prefix", prefix

    # opt_prefix survives `brew upgrade`; the versioned Cellar path doesn't.
    (bin/"scriptrunnerbar").write <<~SH
      #!/bin/sh
      exec open "#{opt_prefix}/ScriptRunnerBar.app"
    SH
  end

  def caveats
    <<~EOS
      Start it with:  scriptrunnerbar
      After `brew upgrade`, toggle Launch at Login off and on once.
    EOS
  end

  test do
    assert_predicate bin/"scriptrunnerbar", :executable?
    app = prefix/"ScriptRunnerBar.app"
    assert_path_exists app/"Contents/Info.plist"
    assert_predicate app/"Contents/MacOS/ScriptRunnerBar", :executable?
    # The signature must be intact or Apple silicon refuses to launch the app.
    system "codesign", "--verify", app
  end
end
