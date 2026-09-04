# ~/.zshenv
# Loaded for ALL zsh shells (login, interactive, non-interactive, scripts)
# Keep this minimal - only truly universal environment variables
#
# Note: This file is the SINGLE SOURCE OF TRUTH for environment variables
# The old .exports file is now deprecated

#=============================================================================
# Editor
#=============================================================================
export EDITOR='vim'

#=============================================================================
# Pi / Agent Beach
#=============================================================================
export AGENT_BEACH_PROFILE=allow-all

#=============================================================================
# Language/Locale
#=============================================================================
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

#=============================================================================
# Node.js REPL
#=============================================================================
export NODE_REPL_HISTORY=~/.node_history
export NODE_REPL_HISTORY_SIZE='32768'  # 32³ entries
export NODE_REPL_MODE='sloppy'         # Match web browser behavior

#=============================================================================
# Python
#=============================================================================
export PYTHONIOENCODING='UTF-8'

#=============================================================================
# Pager/Manual
#=============================================================================
export MANPAGER='less -X'  # Don't clear screen after quitting man

#=============================================================================
# GPG
#=============================================================================
# Avoid issues with `gpg` as installed via Homebrew
# https://stackoverflow.com/a/42265848/96656
export GPG_TTY=$(tty)
