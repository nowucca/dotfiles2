#!/usr/bin/env zsh

cd "$(dirname "${(%):-%x}")"

function ensureGitRepo() {
    local repo_url=$1
    local repo_folder=$2
    [ -r ~/init/$repo_folder ] || (mkdir -p ~/init/$repo_folder && cd ~/init/ && git clone $repo_url)
    (cd ~/init/$repo_folder && git pull -q)
}

function doIt() {
    echo "Syncing dotfiles..."
    
    # Sync main dotfiles (excluding special directories and files)
    rsync --exclude ".git/" \
        --exclude ".DS_Store" \
        --exclude ".osx" \
        --exclude "bootstrap.sh" \
        --exclude "README.md" \
        --exclude "README.netflix_workspaces.md" \
        --exclude "LICENSE-MIT.txt" \
        --exclude "memory_bank/" \
        -avhq --no-perms . ~
    
    # Ensure required git repos
    ensureGitRepo https://github.com/altercation/solarized.git solarized
    ensureGitRepo https://github.com/rupa/z.git z
    
    # Reload shell config
    source ~/.zshrc
    
    echo "Done!"
}

function showHelp() {
    echo "Usage: bootstrap.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --force     Skip confirmation prompt"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "The bootstrap script syncs dotfiles from this repo to your home directory."
    echo ""
    echo "For first-time setup:"
    echo "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "  2. Run: ./bootstrap.sh"
    echo "  3. Run: ./brew.sh (optional, installs common tools)"
}

# Parse arguments
case "$1" in
    -h|--help)
        showHelp
        exit 0
        ;;
    -f|--force)
        doIt
        ;;
    "")
        read -r "REPLY?This may overwrite existing files in your home directory. Are you sure? (y/n) "
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            doIt
        fi
        ;;
    *)
        echo "Unknown option: $1"
        showHelp
        exit 1
        ;;
esac

unset doIt
unset showHelp
unset ensureGitRepo
