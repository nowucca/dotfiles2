# Dotfiles Project Brief

## Overview

Personal dotfiles repository for macOS configuration, shell setup, and Hammerspoon product hosting. The repo holds the source of truth; `bootstrap.sh -f` rsyncs it to `~/`.

## Components

### Shell

`.zshrc`, `.zshenv`, `.tmux.conf`, and the modular `.zsh/` tree (`core/`, `aliases/`, `functions/`, `tools/`, `prompt.zsh`, `netflix.zsh`). No oh-my-zsh; lazy-loaded NVM/SDKMAN; fast git-aware prompt.

### Hammerspoon host

`.hammerspoon/` is a multi-product host. `init.lua` (~37 lines) loads each product listed in `products.lua` and calls its `start()`/`stop()`. Each product owns its menubar widget and lifecycle.

Products themselves live in their own repos under `~/spaces/`. Dotfiles symlinks them into `.hammerspoon/<product>` and bootstrap preserves the symlinks via `rsync -al`.

Currently registered:

| Product | Repo | Status |
|---------|------|--------|
| `spaces` | `~/spaces/hs-spaces/hs-spaces/main` | v1 shipped, v1.5 in progress |

Future products plug in as siblings — drop a folder, add to `products.lua`.

### Dev tools

`.gitconfig`, `.vimrc`, `.editorconfig`, plus `bin/` utility scripts.

## Constraints

- macOS-only for Hammerspoon products. Shell config aims to also work on Linux.
- Zsh as primary shell.
- `bootstrap.sh -f` uses rsync **without** `--delete` — removing a file from the repo doesn't remove it from `~/`. Explicit `rm` required when retiring directories or replacing dirs with symlinks.
- Sensitive data in `.netflix-extra` (gitignored).

## In scope (this repo)

- Shell config (zsh, tmux, prompt) and aliases/functions.
- Git config and editor config.
- The Hammerspoon **host** (init.lua, products.lua) + product symlinks.
- ctx-lenses shell integration (`.zsh/tools/ctx.zsh`).

## Out of scope (this repo)

- The Spaces product itself — that's in `~/spaces/hs-spaces/hs-spaces/main/`. Edit there; dotfiles symlinks pull it in. See that repo's `memory_bank/` for product-specific context.
- Cross-machine sync of user data (`workspace-notes.json`, `space-profiles/`). Those stay in `~/.hammerspoon/`.
- Linux desktop automation.

## Success

- Fresh machine productive in < 30 minutes via `bootstrap.sh`.
- Shell startup < 100ms.
- Hammerspoon products load with no console errors.
- Adding a new product is "drop a repo, symlink, add to products.lua".
