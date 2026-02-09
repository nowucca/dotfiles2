#!/usr/bin/env zsh
#
# Hammerspoon aliases
#

# Only on macOS
is_mac || return 0

alias hss='sync-hammerspoon.sh'                        # Sync hammerspoon config
alias hsr='sync-hammerspoon.sh && hs -c "hs.reload()"' # Sync and reload
alias hsr!='hs -c "hs.reload()"'                       # Just reload (no sync)
alias hsc='hs -c'                                      # Quick Hammerspoon command
alias hsed='cd ~/Work/dotfiles/.hammerspoon'           # Edit hammerspoon dotfiles
