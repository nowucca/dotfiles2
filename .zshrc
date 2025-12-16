#
# ~/.zshrc - Main zsh configuration file
#
# Note:
#  install brew
#  then run bootstrap.sh
#
# to kickstart this dotfiles process on a new machine

# Determine if we are in a virtual workspace or not
# Function to check if we are in a coder workspace
is_coder_workspace() {
  [[ -n "$CODER_WORKSPACENAME" ]]
}

# Function to check if the system is Linux
is_linux() {
  [[ "$(uname)" == "Linux" ]]
}

is_mac() {
  [[ "$(uname -s)" == "Darwin" ]]
}

# Add `~/bin` to the `$PATH`
export PATH="$HOME/bin:$PATH";
if is_mac; then
    # Set PATH, MANPATH, etc., for Homebrew (cached for performance)
    # This replaces slow `eval "$(brew shellenv)"` with hardcoded values
    # If you reinstall Homebrew to a different location, update these paths
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
    export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
fi

# init z https://github.com/rupa/z
if is_coder_workspace; then
  . ~/.config/work/dotfiles/init/z/z.sh
else
  . ~/init/z/z.sh
fi

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don't want to commit.
for file in ~/.{path,zsh_prompt,exports,aliases,functions,history,extra,netflix-extra,npm-globals}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

# GTK path for wireshark GUI to work
GTK_PATH=/usr/local/lib/gtk-2.0

# zsh completions
if is_mac; then
  # Load homebrew's zsh completions first (before compinit)
  if type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  fi

  # Enable zsh completion system with caching (only once!)
  # Regenerate cache only once per day for better performance
  autoload -Uz compinit
  if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
  else
    compinit -C
  fi
fi

# Use emacs key bindings for command line editing
bindkey -e

# Explicitly bind Ctrl-A and Ctrl-E for beginning/end of line
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# Case-insensitive globbing (used in pathname expansion)
setopt NO_CASE_GLOB

# Autocorrect typos in path names when using `cd`
setopt CORRECT
setopt CORRECT_ALL

# Enable extended globbing
# * `**/qux` will match `./foo/bar/baz/qux`
# * Recursive globbing with `**/*.txt`
setopt EXTENDED_GLOB
setopt GLOB_STAR_SHORT

# SSH completion is handled by zsh's built-in completion system (via compinit)
# The bash 'complete' builtin doesn't work in zsh, so the old line has been removed

###################################
# STTY Settings                   #
###################################
# Only run stty commands in interactive shells with a TTY
if [ -t 0 ] && [[ -o interactive ]]; then
  stty -ixon
fi
# stty erase \ intr \ kill \ susp \

# ixon (-ixon) Enable (disable) START/STOP output control
# Output is stopped by sending STOP control character and
# started by sending the START control character.
