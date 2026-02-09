# Dotfiles Project Brief

## Overview
Personal dotfiles repository for macOS configuration, shell setup, and development tools.

## Core Objectives
1. **Portable Configuration** - Consistent dev environment across machines
2. **Version Controlled** - Track changes and history of all config files
3. **Easy Setup** - Bootstrap new machines quickly with `bootstrap.sh`
4. **Modular** - Each tool's config is self-contained

## Key Components

### Shell Configuration
- `.zshrc`, `.zshenv` - Zsh shell configuration
- `.aliases` - Command shortcuts
- `.functions` - Shell functions
- `.exports` - Environment variables
- `.path` - PATH configuration

### Development Tools
- `.gitconfig` - Git configuration
- `.vimrc` - Vim configuration
- `.editorconfig` - Editor settings

### macOS Automation
- `.hammerspoon/` - Hammerspoon configuration for space labeling and workspace management

### Scripts
- `bin/` - Utility scripts
- `bootstrap.sh` - Initial setup script
- `brew.sh` - Homebrew package installation
- `install.sh` - Symlink creation

## Project Constraints
- macOS-focused (some configs may work on Linux)
- Zsh as primary shell
- Uses symlinks from dotfiles repo to home directory
- Private/sensitive data in `.netflix-extra` (not committed)

## Success Criteria
- New machine can be set up in under 30 minutes
- All personal preferences and shortcuts available
- Hammerspoon space labeling works reliably
