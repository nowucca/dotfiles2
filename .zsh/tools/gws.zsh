#!/usr/bin/env zsh
#
# gws - Google Workspace CLI
# Self-heals: installs via npm if gws is missing and npm is available.
#

if ! command -v gws &>/dev/null && command -v npm &>/dev/null; then
    echo "gws not found — installing @googleworkspace/cli..."
    npm install -g @googleworkspace/cli
fi
