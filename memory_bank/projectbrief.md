# Dotfiles Project Brief

## Overview

Personal dotfiles repository for macOS configuration, shell setup, and Hammerspoon-hosted desktop products. The repo holds the source of truth; `bootstrap.sh -f` rsyncs it to `~/`.

## Components

### Shell

`.zshrc`, `.zshenv`, `.tmux.conf`, and the modular `.zsh/` tree (`core/`, `aliases/`, `functions/`, `tools/`, `prompt.zsh`, `netflix.zsh`). No oh-my-zsh; lazy-loaded NVM/SDKMAN; fast git-aware prompt.

### Hammerspoon products

`.hammerspoon/` is a multi-product host. `init.lua` (~37 lines) loads each product listed in `products.lua` and calls its `start()`/`stop()`. Each product owns its menubar widget and lifecycle.

**Spaces** (v1, current): branded macOS-native shell for running long-running AI agents. Tab-title state convention surfaces agent state in the menubar; two hotkeys spawn agents into new spaces or new tabs.

Future products plug in as siblings (e.g. `spaces-hs`, `clipboard`, etc.) by dropping a folder under `.hammerspoon/` and adding the name to `products.lua`.

### Dev tools

`.gitconfig`, `.vimrc`, `.editorconfig`, plus `bin/` utility scripts.

## Constraints

- macOS-only for Hammerspoon products. Shell config aims to also work on Linux.
- Zsh as primary shell.
- `bootstrap.sh -f` uses rsync **without** `--delete` — removing a file from the repo doesn't remove it from `~/`. Explicit `rm` required when retiring directories.
- Sensitive data in `.netflix-extra` (gitignored).

## In scope

- Shell config (zsh, tmux, prompt) and aliases/functions.
- Git config and editor config.
- Hammerspoon products that orchestrate macOS Spaces, agents, and apps.
- Pure-Lua tests for product modules; manual smoke for UI/AppleScript surfaces.

## Out of scope

- Cross-machine sync of user data (`workspace-notes.json`, `space-profiles/`). Those stay in `~/.hammerspoon/` and aren't in the repo.
- Linux desktop automation.
- App-specific configs the dotfiles flow can't reach (e.g. iTerm preferences plist).

## Success

- Fresh machine productive in < 30 minutes via `bootstrap.sh`.
- Shell startup < 100ms.
- Hammerspoon products load with no console errors and work without an IDE in the loop.
- Agent activity visible at a glance from the macOS menubar.
