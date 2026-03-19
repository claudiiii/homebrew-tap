class EmacsMacAT31 < Formula
  desc "YAMAMOTO Mitsuharu's Mac port of GNU Emacs (GNU master experimental)"
  homepage "https://www.gnu.org/software/emacs/"

  # This formula only supports HEAD builds tracking GNU Emacs master
  # Install with: brew install --HEAD emacs-mac@31exp
  head "https://github.com/jdtsmith/emacs-mac.git", branch: "emacs-mac-gnu_master_exp"

  license "GPL-3.0-or-later"

  option "without-modules", "Build without dynamic modules support"
  option "with-no-title-bars", "Build with a patch for no title bars on frames"
  option "with-starter", "Build with a starter script to start emacs GUI from CLI"
  option "with-mac-metal", "use Metal framework in application-side double buffering (experimental)"
  option "with-native-comp", \
         "Build with native compilation (same as \"--with-native-compilation\", for compatibility only)"
  option "with-native-compilation", "Build with native compilation"
  option "with-xwidgets", "Build with xwidgets"
  option "with-unlimited-select", "Builds with unlimited select, which increases emacs's open file limit to 10000"

  depends_on "autoconf"
  depends_on "automake"
  depends_on "gnutls"
  depends_on "pkg-config"
  depends_on "texinfo"
  depends_on "jansson" => :recommended
  depends_on "libxml2" => :recommended
  depends_on "tree-sitter" => :recommended
  depends_on "dbus" => :optional
  depends_on "glib" => :optional
  depends_on "imagemagick" => :optional
  depends_on "librsvg" => :optional

  if (build.with? "native-comp") || (build.with? "native-compilation")
    depends_on "libgccjit" => :recommended
    depends_on "gcc" => :build
  end

  def install
    args = [
      "--enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp",
      "--infodir=#{info}",
      "--mandir=#{man}",
      "--prefix=#{prefix}",
      "--with-mac",
      "--enable-mac-app=#{prefix}",
      "--with-gnutls",
    ]
    args << "--with-modules" if build.with? "modules"
    args << "--with-rsvg" if build.with? "rsvg"
    args << "--with-mac-metal" if build.with? "mac-metal"
    args << "--with-native-compilation" if (build.with? "native-comp") || (build.with? "native-compilation")
    args << "--with-xwidgets" if build.with? "xwidgets"
    args << "--with-tree-sitter" if build.with? "tree-sitter"

    if (build.with? "native-comp") || (build.with? "native-compilation")
      gcc_ver = Formula["gcc"].any_installed_version
      gcc_ver_major = gcc_ver.major
      gcc_lib="#{HOMEBREW_PREFIX}/lib/gcc/#{gcc_ver_major}"

      ENV.append "CFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "CFLAGS", "-I#{Formula["libgccjit"].include}"

      ENV.append "LDFLAGS", "-L#{gcc_lib}"
      ENV.append "LDFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "LDFLAGS", "-I#{Formula["libgccjit"].include}"
    end

    if build.with? "unlimited-select"
      ENV.append "CFLAGS", "-DFD_SETSIZE=10000"
      ENV.append "CFLAGS", "-DDARWIN_UNLIMITED_SELECT"
    end

    system "./autogen.sh"
    system "./configure", *args
    system "make"
    system "make", "install"
    prefix.install "NEWS-mac"

    if build.with? "starter"
      # Replace the symlink with one that starts GUI
      # alignment the behavior with cask
      # borrow the idea from emacs-plus
      (bin/"emacs").unlink
      (bin/"emacs").write <<~EOS
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs.sh "$@"
      EOS
    end
  end

  def post_install
    if (build.with? "native-comp") || (build.with? "native-compilation")
      ln_sf "#{Dir[prefix/"lib/emacs/*"].first}/native-lisp", "#{prefix}/Emacs.app/Contents/native-lisp"
    end
    (info/"dir").delete if (info/"dir").exist?
    info.glob("*.info{,.gz}") do |f|
      quiet_system Formula["texinfo"].bin/"install-info", "--quiet", "--info-dir=#{info}", f
    end
  end

  def caveats
    <<~EOS
      This is a HIGHLY EXPERIMENTAL build of YAMAMOTO Mitsuharu's "Mac port"
      tracking GNU Emacs master branch, based on jdtsmith's fork.

      WARNING: This tracks bleeding-edge development. Expect breakage.
      Use at your own risk.

      This provides a native GUI support for macOS.
      After installing, see README-mac and NEWS-mac in #{prefix} for the port details.

      Emacs.app was installed to:
        #{prefix}

      To link the application to default App location and CLI scripts, please checkout:
        https://github.com/railwaycat/homebrew-emacsmacport/blob/master/docs/emacs-start-helpers.md

      If you are using Doom Emacs, be sure to run doom sync:
        ~/.emacs.d/bin/doom sync

      For an Emacs.app CLI starter, see:
        https://gist.github.com/4043945
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
