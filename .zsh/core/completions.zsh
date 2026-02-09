#!/usr/bin/env zsh
#
# Completion system configuration - optimized for startup speed
#

if is_mac; then
    # Add local completion scripts to FPATH
    fpath=(~/.local/share/zsh/site-functions $fpath)

    # Load homebrew's zsh completions (before compinit)
    if [[ -d "$(brew --prefix)/share/zsh/site-functions" ]] 2>/dev/null; then
        FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    fi
fi

# Enable zsh completion system with caching
# Regenerate cache only once per day for better performance
autoload -Uz compinit

# Check if dump file exists and is less than 24 hours old
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    # Dump is old or doesn't exist - regenerate
    compinit
    # Pre-compile for faster loading next time
    { zcompile "${ZDOTDIR:-$HOME}/.zcompdump" } &!
else
    # Use cached completions
    compinit -C
fi

# Completion styling
zstyle ':completion:*' menu select                          # Use menu selection
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # Colorize completions
zstyle ':completion:*:descriptions' format '%B%d%b'        # Bold descriptions
