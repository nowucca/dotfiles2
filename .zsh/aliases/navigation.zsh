#!/usr/bin/env zsh
#
# Navigation and directory aliases
#

# Easier navigation: .., ..., ...., .....
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"

# Only set the '-' alias in interactive shells
if [[ $- == *i* ]]; then
    alias -- -="cd -"
fi

# Common directories
alias d="cd ~/Documents/Dropbox"
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias doc="cd ~/Documents"
alias p="cd ~/projects"

# Directory stack
alias dv='dirs -v'
alias dh='dirs -v | head -11'

# Dotfiles shortcuts
alias dotf="cd ~/Work/dotfiles"
alias dotsync="sync-dotfiles.sh"
alias dotb="cd ~/Work/dotfiles; . ./bootstrap.sh -f"
alias rz='. ~/.zshrc'
alias zz='vi ~/Work/dotfiles/.zshrc'
alias resource='source $HOME/.zshrc'
