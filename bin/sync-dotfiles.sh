#!/bin/sh

echo Installing nowucca dotfiles....
cd $HOME/dotfiles/nowucca/dotfiles
source bootstrap.sh
echo Installing dvd.netflix.com dotfiles....
cd $HOME/dotfiles/dvd.netflix.com/dotfiles
source bootstrap.sh
echo Installing brew formulae....
cd $HOME
brew bundle Brewfile
echo Installing brew casks....
brew bundle Caskfile
echo "Run . ./.osx to re-initialize OSX tweaks."