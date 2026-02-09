#!/usr/bin/env zsh
#
# Zsh options and settings
#

# Case-insensitive globbing (used in pathname expansion)
setopt NO_CASE_GLOB

# Autocorrect typos in command names (not arguments)
setopt CORRECT

# Enable extended globbing
# * `**/qux` will match `./foo/bar/baz/qux`
# * Recursive globbing with `**/*.txt`
setopt EXTENDED_GLOB
setopt GLOB_STAR_SHORT

# Use emacs key bindings for command line editing
bindkey -e

# Explicitly bind Ctrl-A and Ctrl-E for beginning/end of line
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# STTY Settings - Only run in interactive shells with a TTY
if [ -t 0 ] && [[ -o interactive ]]; then
  stty -ixon
fi
# ixon (-ixon) Enable (disable) START/STOP output control
# Output is stopped by sending STOP control character and
# started by sending the START control character.
