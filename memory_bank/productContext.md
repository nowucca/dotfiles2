# Product Context — Dotfiles

## Why this repo

A personal dotfiles repo with two responsibilities:

1. **Portable dev environment.** Consistent zsh, tmux, git config across machines. New machine gets productive fast via `bootstrap.sh`.
2. **Hammerspoon host for desktop products.** The `.hammerspoon/` directory is a thin multi-product host. Products live in their own repos under `~/spaces/`; dotfiles symlinks them in.

## User stories — dotfiles side

- *I'm setting up a new machine.* Clone, run `./bootstrap.sh -f`, get productive in 30 minutes.
- *I want to update an alias.* Edit in `.zsh/aliases/`, run bootstrap, reload shell.
- *I added a new Hammerspoon product.* Symlink it under `.hammerspoon/`, add to `products.lua`, reload.
- *Slow shell startup.* Profile via `time zsh -i -c exit`; usual suspects are non-lazy tool init.

For Spaces product user stories, see `~/spaces/hs-spaces/hs-spaces/main/memory_bank/productContext.md`.

## UX goals — shell

- Shell startup < 100ms.
- Aliases short and memorable.
- Powerful navigation (z, directory shortcuts).
- Git status in prompt; fast mode for huge repos.
- Tools that are slow at init (NVM, SDKMAN) lazy-load on first use.

## UX goals — Hammerspoon host

- Adding a product is mechanical (drop a folder/symlink, add a name to `products.lua`).
- Reload via `hs.reload()` cleanly tears down and rebuilds — no leaked watchers or widgets.
- The host stays small (~37 lines).

## Success metrics

- Fresh machine productive: < 30 min.
- Shell startup: < 100ms (verified by `time zsh -i -c exit`).
- Hammerspoon products load without errors at info level.
