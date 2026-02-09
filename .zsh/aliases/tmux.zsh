#!/usr/bin/env zsh
#
# Tmux aliases and functions
#

# Basic aliases
alias tm='tmux'
alias tma='tmux attach'
alias tmat='tmux attach -t'
alias tmls='tmux list-sessions'
alias tmks='tmux kill-session -t'
alias tmka='tmux kill-server'

# Quick session management
alias tms='tmux new-session -s'        # tms <name> - create new named session
alias tmd='tmux detach'                 # detach from current session

# Attach to session or create if doesn't exist
function tmx() {
    local session="${1:-main}"
    tmux attach -t "$session" 2>/dev/null || tmux new-session -s "$session"
}

# List sessions with preview
function tmpl() {
    if ! tmux list-sessions 2>/dev/null; then
        echo "No tmux sessions running"
        return 1
    fi
}

# Kill session interactively (with fzf if available)
function tmkill() {
    if command -v fzf &>/dev/null; then
        local session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --prompt="Kill session: ")
        [[ -n "$session" ]] && tmux kill-session -t "$session"
    else
        tmux list-sessions 2>/dev/null
        echo -n "Session to kill: "
        read session
        [[ -n "$session" ]] && tmux kill-session -t "$session"
    fi
}

# Create a development session with standard layout
function tmdev() {
    local session="${1:-dev}"
    local dir="${2:-.}"
    
    tmux new-session -d -s "$session" -c "$dir"
    tmux rename-window -t "$session:1" 'editor'
    tmux new-window -t "$session:2" -n 'shell' -c "$dir"
    tmux new-window -t "$session:3" -n 'server' -c "$dir"
    tmux select-window -t "$session:1"
    tmux attach -t "$session"
}
