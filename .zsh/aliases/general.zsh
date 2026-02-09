#!/usr/bin/env zsh
#
# General shell aliases
#

# History
alias h="history"
alias rh=". ~/.history"
alias hi='fc -l'

# Basic commands
alias c=clear
alias cls=clear
alias copy=cp
alias cp='cp -i'
alias del=rm
alias mv='/bin/mv -i'
alias rm='rm -i'
alias rd=rmdir
alias m='more'
alias f=finger
alias t=telnet
alias s=ssh
alias d2u='dos2unix'

# Enable aliases to be sudo'ed
alias sudo='sudo '

# Shell reload
alias reload="exec $SHELL -l"

# Job control
alias j='jobs -l'
alias 1='fg %1'
alias 2='fg %2'
alias 3='fg %3'
alias 4='fg %4'
alias 5='fg %5'
alias k1='kill %1'
alias k2='kill %2'
alias k3='kill %3'
alias k4='kill %4'
alias k5='kill %5'
alias sus='kill -STOP $$'

# Editor
alias e='emacs -nw'
alias edit='emacs'

# Terminal
alias term='echo $TERM'
alias disp='echo $DISPLAY'
alias nodisp='export DISPLAY='
