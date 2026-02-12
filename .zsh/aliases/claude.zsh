#!/usr/bin/env zsh
#
# Claude AI CLI aliases
#

# Shortcut for running Claude with dangerous permissions (skips approval prompts)
alias clauded='claude --dangerously-skip-permissions'

# Resume a previous Claude session with dangerous permissions
alias claudedr='claude --dangerously-skip-permissions --resume'
