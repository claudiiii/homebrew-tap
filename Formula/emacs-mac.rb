class EmacsMac < Formula
  desc "YAMAMOTO Mitsuharu's Mac port of GNU Emacs (Emacs 30 experimental)"
  homepage "https://www.gnu.org/software/emacs/"

  # Using jdtsmith's fork with Emacs 30 mac port patches
  # No tagged releases - pin to specific commit hash
  url "https://github.com/jdtsmith/emacs-mac/archive/880eef8aeef7ba6346078404a09522ffc5fd3d8d.tar.gz"
  version "emacs-30-20260201"
  sha256 "64f74a2691db669cfce206f6a8c95135b871908df7eedcb12f904d0e33bf0343"

  option "with-ctags", "Don't remove the ctags executable that emacs provides"
  option "with-starter", "Build with a starter script to start emacs GUI from CLI"
  option "with-unlimited-select", "Builds with unlimited select, which increases emacs's open file limit to 10000"

  depends_on "gcc" => :build

  depends_on "autoconf"
  depends_on "automake"
  depends_on "gnutls"
  depends_on "jansson"
  depends_on "libgccjit"
  depends_on "librsvg"
  depends_on "libxml2"
  depends_on "pkgconf"
  depends_on "texinfo"
  depends_on "tree-sitter@0.25"

  resource "assets" do
    url "https://github.com/jimeh/emacs-liquid-glass-icons/raw/refs/heads/main/Resources/Assets.car"
    sha256 "d574c2f3bd809f2b47c9fa9907727cd3911dc09991631bdec65d6c4e79ad6538"
  end

  resource "icon" do
    url "https://github.com/jimeh/emacs-liquid-glass-icons/raw/refs/heads/main/Resources/EmacsLG3-Default.icns"
    sha256 "beef90a1324b901fc46e213ae9db893546079b9596a85671efbc302813b9c497"
  end

  patch "diff --git a/mac/templates/Info.plist.in b/mac/templates/Info.plist.in
  index 50a159acabc..d9fdf3484ba 100644
  --- a/mac/templates/Info.plist.in
  +++ b/mac/templates/Info.plist.in
  @@ -570,6 +570,8 @@ along with GNU Emacs Mac port.  If not, see <http://www.gnu.org/licenses/>.
   	<string>Emacs</string>
   	<key>CFBundleIconFile</key>
   	<string>Emacs.icns</string>
  +	<key>CFBundleIconName</key>
  +	<string>EmacsLG3</string>
   	<key>CFBundleIdentifier</key>
   	<string>org.gnu.Emacs</string>
   	<key>CFBundleInfoDictionaryVersion</key>
  --"

  patch "diff --git a/src/macappkit.m b/src/macappkit.m
  index fe7524ce629..97ae0f7439f 100644
  --- a/src/macappkit.m
  +++ b/src/macappkit.m
  @@ -8692,10 +8692,10 @@ - (NSAppearance *)effectiveAppearance
        horizontally adjacent fringe-less Emacs windows with scroll bars.
        So we change EmacsScroller's appearance to NSAppearanceNameAqua
        if otherwise it becomes NSAppearanceNameVibrantLight.  */
  -  if ([effectiveAppearance.name
  -	  isEqualToString:NSAppearanceNameVibrantLight])
  -    return [NSAppearance appearanceNamed:NSAppearanceNameAqua];
  -  else
  +  // if ([effectiveAppearance.name
  +  // 	  isEqualToString:NSAppearanceNameVibrantLight])
  +  //   return [NSAppearance appearanceNamed:NSAppearanceNameAqua];
  +  // else
       return effectiveAppearance;
   }

  --"

  def install
    args = [
      "--enable-locallisppath=#{opt_elisp}",
      "--infodir=#{info}",
      "--mandir=#{man}",
      "--prefix=#{prefix}",
      "--with-mac",
      "--enable-mac-app=#{prefix}",
      "--with-native-compilation",
      "--with-tree-sitter",
      # "--with-gnutls",
      # "--with-mac-metal"
    ]

    gcc_ver = Formula["gcc"].any_installed_version
    gcc_ver_major = gcc_ver.major
    gcc_lib="#{HOMEBREW_PREFIX}/lib/gcc/#{gcc_ver_major}"

    ENV.append "CFLAGS", "-O3"
    ENV.append "CFLAGS", "-march=native"
    ENV.append "CFLAGS", "-fobjc-arc"
    ENV.append "CFLAGS", "-I#{Formula["gcc"].include}"
    ENV.append "CFLAGS", "-I#{Formula["libgccjit"].include}"

    ENV.append "LDFLAGS", "-L#{gcc_lib}"
    ENV.append "LDFLAGS", "-I#{Formula["gcc"].include}"
    ENV.append "LDFLAGS", "-I#{Formula["libgccjit"].include}"

    if build.with? "unlimited-select"
      ENV.append "CFLAGS", "-DFD_SETSIZE=10000"
      ENV.append "CFLAGS", "-DDARWIN_UNLIMITED_SELECT"
    end

    # Desperate try to prevent the Homebrew shims directory in the output
    # but doesn't seem to work.
    ENV.append "PKG_CONFIG", Formula["pkgconf"].opt_bin/"pkg-config"

    resources_dir = buildpath/"mac/Emacs.app/Contents/Resources"
    rm "#{resources_dir}/Emacs.icns"
    resource("icon").stage do
      resources_dir.install "EmacsLG3-Default.icns" => "Emacs.icns"
    end

    resource("assets").stage do
      resources_dir.install "Assets.car" => "Assets.car"
    end

    system "./autogen.sh"
    system "./configure", *args
    system "make"
    system "make", "install"
    prefix.install "NEWS-mac"

    # Follow Homebrew and don't install ctags from Emacs. This allows Vim
    # and Emacs and exuberant ctags to play together without violence.
    if build.without? "ctags"
      (bin/"ctags").unlink
      (share/man/man1/"ctags.1.gz").unlink
    end

    if build.with? "starter"
      # Replace the symlink with one that starts GUI.
      # Better alignment with the cask behaviour,
      # idea borrowed from emacs-plus.
      (bin/"emacs").unlink
      (bin/"emacs").write <<~EOS
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs.sh "$@"
      EOS
    end
  end

  def post_install
    ln_sf "#{Dir[prefix/"lib/emacs/*"].first}/native-lisp", "#{prefix}/Emacs.app/Contents/native-lisp"
    (info/"dir").delete if (info/"dir").exist?
    info.glob("*.info{,.gz}") do |f|
      quiet_system Formula["texinfo"].bin/"install-info", "--quiet", "--info-dir=#{info}", f
    end
  end

  def caveats
    <<~EOS
      This is an EXPERIMENTAL build of YAMAMOTO Mitsuharu's "Mac port"
      for GNU Emacs 30, based on jdtsmith's fork.
      Follow the upstream development here: https://github.com/jdtsmith/emacs-mac

      This formula provides native GUI support for macOS 12 - macOS 26.
      See #{prefix}/NEWS-mac and #{prefix}/README-mac for the latest updates.

      To install Emacs.app copy or move it from #{prefix} to /Applications.

      For aditional Emacs.app hacks and CLI starter scripts, see:
        https://github.com/railwaycat/homebrew-emacsmacport/blob/master/docs/emacs-start-helpers.md
      and for even more options see this gist:
        https://gist.github.com/4043945
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
