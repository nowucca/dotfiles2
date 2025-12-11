#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install a modern version of Bash.
brew install bash
brew install bash-completion@2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Install `wget` with IRI support.
brew install wget 

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install vim --with-override-system-vi
brew install grep
brew install openssh
brew install openssl
brew install screen
brew install php
brew install gmp

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Install some CTF tools; see https://github.com/ctfs/write-ups.
brew install aircrack-ng
brew install bfg
brew install binutils
brew install binwalk
brew install cifer
brew install dex2jar
brew install dns2tcp
brew install fcrackzip
brew install foremost
brew install hashpump
brew install hydra
brew install john
brew install knock
brew install netpbm
brew install nmap
brew install pngcheck
brew install socat
brew install sqlmap
brew install tcpflow
brew install tcpreplay
brew install tcptrace
brew install ucspi-tcp # `tcpserver` etc.
brew install xpdf
brew install xz

# Install Kotlin
brew install kotlin

# Install other useful binaries.
brew install ack
#brew install exiv2
brew install git
brew install git-lfs
brew install git-credential-manager
brew install gs
brew install imagemagick --with-webp
brew install lua
brew install lynx
brew install p7zip
brew install pigz
brew install pv
brew install rename
brew install rlwrap
brew install ssh-copy-id
brew install tree
brew install vbindiff
brew install zopfli

# Install my binaries.
brew install maven31
brew install node
brew install wireshark --with-lua
brew install docker
brew install docker-machine
brew install id3lib
brew install xmlstarlet
brew install kdiff3
brew install gpg
brew install ag
brew install gradle
brew install lz4
brew install jq
brew install rpm
brew install golang
brew install maven@3.6

# Install my cask-based binaries.
#brew install phinze/cask/brew-cask
brew tap homebrew/cask
brew tap caskroom/versions
brew cask install alfred
brew cask install hazel
brew cask install perforce
brew cask install p4v
brew cask install github 
brew cask install google-chrome 
brew cask install slack
brew cask install imagealpha 
brew cask install imageoptim 
brew cask install iterm2 
brew cask install macvim
brew cask install miro-video-converter 
brew cask install opera 
brew cask install sublime-text 
brew cask install the-unarchiver 
brew cask install thunderbird 
brew cask install transmission 
brew cask install ukelele 
brew cask install virtualbox 
brew cask install vlc 

brew cask install gimp
brew cask install macvim
brew cask install kdiff3

brew cask install remote-desktop-connection

brew cask install little-snitch
brew cask install micro-snitch

# Security tool
brew cask install owasp-zap

#Ext4
brew cask install osxfuse
brew install ext4fuse

#Utilities
brew install dos2unix
brew install bzip2
brew install geoip

# GPG suite
brew cask install gpg-suite

# TCL 
brew cask install tcl

#Java
brew install jenv

#Github
brew install gh

# Blockchain
#brew tap paritytech/paritytech

# MYSQL
brew install mysql
brew cask install mysqlworkbench
#brew install parity --stable

#GRPC 
brew install grpcurl
brew install grpcui

#Powershell for Mac
brew install --cask powershell

#Security
brew install dependency-check

# Google Builds
brew install bazel

# Remove outdated versions from the cellar.
brew cleanup
