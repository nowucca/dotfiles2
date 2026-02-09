#!/usr/bin/env zsh
#
# History configuration
#

# Increase history size. Allow 32³ entries; the default is 500.
export HISTSIZE='32768'
export SAVEHIST="${HISTSIZE}"
export HISTFILE=~/.zsh_history

# History options
setopt HIST_IGNORE_ALL_DUPS  # Remove older duplicates
setopt HIST_IGNORE_SPACE     # Don't record commands starting with space
setopt HIST_SAVE_NO_DUPS     # Don't write duplicates to history file
setopt SHARE_HISTORY         # Share history between sessions
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks
setopt INC_APPEND_HISTORY    # Add commands immediately (not on exit)
