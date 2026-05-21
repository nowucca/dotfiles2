#
# ~/.zshrc - Main zsh configuration file
#
# Architecture:
#   .zshenv     - Environment variables (loaded for ALL shells)
#   .zshrc      - Interactive shell config (this file)
#   .zsh/       - Modular configuration
#     core/       - Options, PATH, history, completions
#     aliases/    - Organized by topic
#     functions/  - Shell functions
#     tools/      - Lazy-loaded tools (NVM, SDKMAN, etc.)
#     prompt.zsh  - Prompt configuration
#     netflix.zsh - Work-specific config
#
# Startup: run bootstrap.sh after installing brew on a new machine

#=============================================================================
# Platform Detection (available to all modules)
#=============================================================================

is_coder_workspace() { [[ -n "$CODER_WORKSPACENAME" ]]; }
is_linux() { [[ "$(uname)" == "Linux" ]]; }
is_mac() { [[ "$(uname -s)" == "Darwin" ]]; }

#=============================================================================
# Module Loading
#=============================================================================

# Load all modules from .zsh directory
# Order matters: core first, then tools, then aliases, then functions, then extras
_zsh_dir="${HOME}/.zsh"

if [[ -d "$_zsh_dir" ]]; then
    # Core settings (path, history, options) - load first
    for file in "$_zsh_dir"/core/*.zsh(N); do
        source "$file"
    done

    # Tools (z, nvm, sdkman) - lazy loaded where possible
    for file in "$_zsh_dir"/tools/*.zsh(N); do
        source "$file"
    done

    # Prompt
    [[ -f "$_zsh_dir/prompt.zsh" ]] && source "$_zsh_dir/prompt.zsh"

    # Aliases (organized by topic)
    for file in "$_zsh_dir"/aliases/*.zsh(N); do
        source "$file"
    done

    # Functions
    for file in "$_zsh_dir"/functions/*.zsh(N); do
        source "$file"
    done

    # Work-specific config (Netflix)
    [[ -f "$_zsh_dir/netflix.zsh" ]] && source "$_zsh_dir/netflix.zsh"
fi

unset _zsh_dir

#=============================================================================
# Local Overrides
#=============================================================================

# ~/.extra can be used for settings you don't want to commit
[[ -f ~/.extra ]] && source ~/.extra

#=============================================================================
# Startup Benchmarking
#=============================================================================

# Uncomment to benchmark shell startup time
# alias zshtime='for i in {1..5}; do time zsh -i -c exit; done'

# Quick benchmark: time zsh -i -c exit

eval "$(command ctx-lenses setup zsh)"

#=============================================================================
# Defensive: clear init.templateDir
#=============================================================================
# Workspace bootstrap can install a template HEAD via symlink to the dotfiles
# source file. `git clone` (a) preserves symlinks when copying templates and
# then (b) writes "ref: refs/heads/.invalid" into the new repo's HEAD as a
# sentinel before resolving the remote default. That write transits the
# symlink and corrupts the dotfiles source, breaking every subsequent clone.
# Unset init.templateDir on every shell start so stale configs can't bite.
git config --file ~/.config/git/config --unset init.templateDir 2>/dev/null || true
git config --file ~/.gitconfig --unset init.templateDir 2>/dev/null || true

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/home/coder/.sdkman"
[[ -s "/home/coder/.sdkman/bin/sdkman-init.sh" ]] && source "/home/coder/.sdkman/bin/sdkman-init.sh"
