#!/usr/bin/env zsh
#
# Shell prompt based on the Solarized Dark theme
# iTerm → Profiles → Text → use 13pt Monaco with 1.1 vertical spacing
#

# Enable prompt substitution
setopt PROMPT_SUBST

# Set terminal type
if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
    export TERM='gnome-256color'
elif infocmp xterm-256color >/dev/null 2>&1; then
    export TERM='xterm-256color'
fi

# Git prompt function with fast mode for large repos
prompt_git() {
    local s=''
    local branchName=''

    # Check if the current directory is in a Git repository
    git rev-parse --is-inside-work-tree &>/dev/null || return

    # Get branch name
    branchName="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || \
        git describe --all --exact-match HEAD 2> /dev/null || \
        git rev-parse --short HEAD 2> /dev/null || \
        echo '(unknown)')"

    # Fast mode for large repos where dirty checks are too slow
    local repoUrl="$(git config --get remote.origin.url)"
    local use_fast_mode=0

    # Check if it's a known large repo
    if grep -qE '(chromium/src\.git|github\.com[:/]Netflix|stash\.corp\.netflix\.com|code\.corp\.netflix\.com)' <<< "${repoUrl}"; then
        use_fast_mode=1
    else
        # Check repo size - if .git dir is > 100MB, use fast mode
        local git_dir_size=$(du -sm "$(git rev-parse --git-dir)" 2>/dev/null | cut -f1)
        if [[ -n "$git_dir_size" ]] && (( git_dir_size > 100 )); then
            use_fast_mode=1
        fi
    fi

    if (( use_fast_mode )); then
        # Fast mode: just show branch and a marker
        s+='⚡'
    else
        # Full mode: detailed status checks for small repos
        if ! $(git diff --quiet --ignore-submodules --cached); then
            s+='+' # Uncommitted changes in index
        fi
        if ! $(git diff-files --quiet --ignore-submodules --); then
            s+='!' # Unstaged changes
        fi
        if [ -n "$(git ls-files --others --exclude-standard)" ]; then
            s+='?' # Untracked files
        fi
        if $(git rev-parse --verify refs/stash &>/dev/null); then
            s+='$' # Stashed files
        fi
    fi

    [ -n "${s}" ] && s=" [${s}]"

    echo -e "${1}${branchName}${2}${s}"
}

# Set up colors
if tput setaf 1 &> /dev/null; then
    tput sgr0 # reset colors
    bold=$(tput bold)
    reset=$(tput sgr0)
    # Solarized colors
    black=$(tput setaf 0)
    blue=$(tput setaf 33)
    cyan=$(tput setaf 37)
    green=$(tput setaf 64)
    orange=$(tput setaf 166)
    purple=$(tput setaf 125)
    red=$(tput setaf 124)
    violet=$(tput setaf 61)
    white=$(tput setaf 15)
    yellow=$(tput setaf 136)
else
    bold=''
    reset="\e[0m"
    black="\e[1;30m"
    blue="\e[1;34m"
    cyan="\e[1;36m"
    green="\e[1;32m"
    orange="\e[1;33m"
    purple="\e[1;35m"
    red="\e[1;31m"
    violet="\e[1;35m"
    white="\e[1;37m"
    yellow="\e[1;33m"
fi

# Highlight the user name when logged in as root
if [[ "${USER}" == "root" ]]; then
    userStyle="${red}"
else
    userStyle="${orange}"
fi

# Highlight the hostname when connected via SSH
if [[ "${SSH_TTY}" ]]; then
    hostStyle="${bold}${red}"
else
    hostStyle="${yellow}"
fi

# Build the prompt
PROMPT='%{%f%k%}'                                                     # reset colors
PROMPT+='%{${bold}%}'$'\n'                                           # newline
PROMPT+="%{${userStyle}%}%n"                                         # username
PROMPT+="%{${white}%} at "
PROMPT+="%{${hostStyle}%}%m"                                         # hostname
PROMPT+="%{${white}%} in "
PROMPT+="%{${green}%}%~"                                             # working directory
PROMPT+='$(prompt_git "%{${white}%} on %{${violet}%}" "%{${blue}%}")' # Git info
PROMPT+=$'\n'
PROMPT+="%{${white}%}\$ %{${reset}%}"                                # $ prompt

# Continuation prompt
PS2="%{${yellow}%}→ %{${reset}%}"
