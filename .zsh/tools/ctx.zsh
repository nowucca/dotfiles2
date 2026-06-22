#!/usr/bin/env zsh
# ctx-lenses shell integration
# Provides: ctx/c aliases, cd switching, tab completion, __ctx_ps1 prompt helper

# Install ctx-lenses via newt if not present
if ! command -v ctx-lenses &>/dev/null; then
    newt --app-type=python cli install ctx-lenses > /dev/null 2>&1
fi

# Only wire up shell integration if the binary is available
if command -v ctx-lenses &>/dev/null; then
    eval "$(command ctx-lenses setup zsh)"
fi
