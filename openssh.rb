#
# Resurected from https://github.com/Homebrew/homebrew-dupes/blob/d12c883fa921398e9f15c9c8d925d513a2a4cc98/openssh.rb
# Adapted from https://github.com/manuelRiel/homebrew-versions/blob/master/openssh65.rb
#

require "formula"

class Openssh < Formula
  homepage "http://www.openssh.com/"
  url "http://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-6.5p1.tar.gz"
  version "6.5p1"
  sha256 "6e074df538f357d440be6cf93dc581a21f22d39e236f217fcd8eacbb6c896cfe"

  option "with-keychain-support", "Add native OS X Keychain and Launch Daemon support to ssh-agent"
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"
  option 'with-hpn-ssh', 'Add Pittsburgh University HPN-SSH Patch'

  depends_on "autoconf" => :build if build.with? "keychain-support"
  depends_on "openssl" => :recommended
  depends_on "libressl" => :optional
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  def patches
    p = []
    # Apply a revised version of Simon Wilkinson's gsskex patch (http://www.sxw.org.uk/computing/patches/openssh.html), which has also been included in Apple's openssh for a while
    p << 'http://downloads.sourceforge.net/project/hpnssh/HPN-SSH%2014v4%206.5p1/openssh-6.5p1-hpnssh14v4.diff.gz' if build.with? 'hpn-ssh'
    p << 'https://gist.github.com/kruton/8951373/raw/a05b4a2d50bbac68e97d4747c1a34b53b9a941c4/openssh-6.5p1-apple-keychain.patch' if build.with? 'keychain-support'
    p
  end

  patch do
    url "https://gist.githubusercontent.com/jacknagel/e4d68a979dca7f968bdb/raw/f07f00f9d5e4eafcba42cc0be44a47b6e1a8dd2a/sandbox.diff"
    sha256 "82c287053eed12ce064f0b180eac2ae995a2b97c6cc38ad1bdd7626016204205"
  end

  # # Patch for SSH tunnelling issues caused by launchd changes on Yosemite
  # patch do
  #   url "https://trac.macports.org/export/135165/trunk/dports/net/openssh/files/launchd.patch"
  #   sha256 "02e76c153d2d51bb0b4b0e51dd7b302469bd24deac487f7cca4ee536928bceef"
  # end

  def install
    system "autoreconf -i" if build.with? "keychain-support"

    if build.with? "keychain-support"
      ENV.append "CPPFLAGS", "-D__APPLE_LAUNCHD__ -D__APPLE_KEYCHAIN__"
      ENV.append "LDFLAGS", "-framework CoreFoundation -framework SecurityFoundation -framework Security"
    end

    ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

    args = %W[
      --with-libedit
      --with-pam
      --with-kerberos5
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
    ]

    args << "--with-ssl-dir=#{Formula["libressl"].opt_prefix}" if build.with? "libressl"
    args << "--with-ldns" if build.with? "ldns"
    args << "--without-openssl-header-check"

    system "./configure", *args
    system "make"
    system "make", "install"
  end

  def caveats
    if build.with? "keychain-support" then <<-EOS.undent
        NOTE: replacing system daemons is unsupported. Proceed at your own risk.

        For complete functionality, please modify:
          /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist

        and change ProgramArguments from
          /usr/bin/ssh-agent
        to
          #{HOMEBREW_PREFIX}/bin/ssh-agent

        You will need to restart or issue the following commands
        for the changes to take effect:

          launchctl unload /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist
          launchctl load /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist

        After that, you can start storing private key passwords in
        your OS X Keychain.
      EOS
    end
  end
end
