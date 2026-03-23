#!/usr/bin/env zsh
#
# NVM - Node Version Manager (Lazy loaded for ~1000ms savings)
#

export NVM_DIR="$HOME/.nvm"

# Install NVM if not present
[ ! -d "$NVM_DIR" ] && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash

# Lazy-load NVM - only initializes when you first use nvm, node, npm, or npx
# Each wrapper unsets ALL wrappers first, loads nvm, then calls the real command.
# This avoids infinite recursion if _load_nvm isn't available as a function
# (e.g. in non-interactive shells spawned by tools like Claude Code).

nvm() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm "$@"
}

node() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use 18 >/dev/null 2>&1
    node "$@"
}

npm() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use 18 >/dev/null 2>&1
    npm "$@"
}

npx() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use 18 >/dev/null 2>&1
    npx "$@"
}
