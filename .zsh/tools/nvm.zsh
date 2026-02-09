#!/usr/bin/env zsh
#
# NVM - Node Version Manager (Lazy loaded for ~1000ms savings)
#

export NVM_DIR="$HOME/.nvm"

# Install NVM if not present
[ ! -d "$NVM_DIR" ] && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash

# Lazy-load NVM - only initializes when you first use nvm, node, npm, or npx
_load_nvm() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    # Default to node 18
    nvm use 18 >/dev/null 2>&1
}

nvm() {
    _load_nvm
    nvm "$@"
}

node() {
    _load_nvm
    node "$@"
}

npm() {
    _load_nvm
    npm "$@"
}

npx() {
    _load_nvm
    npx "$@"
}
