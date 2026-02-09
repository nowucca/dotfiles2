#!/usr/bin/env zsh
#
# PATH configuration - Single source of truth for all PATH settings
#

# Start with a clean, explicit base PATH
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

# macOS/Homebrew paths (hardcoded for performance - avoids slow `eval "$(brew shellenv)"`)
if is_mac; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
    export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
    
    # Netflix paths (if available)
    [[ -d /opt/nflx ]] && export PATH="$PATH:/opt/nflx:/opt/nflx/bin"
    
    # kubectl
    [[ -d "$HOME/.kube/bin" ]] && export PATH="$HOME/.kube/bin:$PATH"
fi

# Add current directory (careful with this in production)
export PATH="$PATH:."

# GTK path for wireshark GUI
export GTK_PATH=/usr/local/lib/gtk-2.0
