# Active Context — Dotfiles

## Current focus

Hammerspoon Spaces product **extracted to its own repo** at `~/spaces/hs-spaces/hs-spaces/main/`. Dotfiles serves as the host: tiny `init.lua` + `products.lua`, with `.hammerspoon/spaces` and `.zsh/tools/spaces.zsh` as symlinks into the new repo.

For active work on the Spaces product itself, see that repo's `memory_bank/activeContext.md`.

## Recent decisions (dotfiles-side)

### 2026-05-08: Spaces extraction → symlinks

Lua product moved out of dotfiles into `~/spaces/hs-spaces/hs-spaces/main/hammerspoon/spaces/`. Dotfiles' `.hammerspoon/spaces` is now an absolute-path symlink. `bootstrap.sh` preserves symlinks via `rsync -al`. First-time cutover required `rm -rf ~/.hammerspoon/spaces` so rsync could lay down the symlink (rsync without `--delete` won't replace a directory with a symlink).

### 2026-05-08: Multi-product Hammerspoon host

`.hammerspoon/init.lua` is a ~37-line host. `products.lua` lists product folder names; the host loads each, calls `start()`. `hs.shutdownCallback` calls each `stop()` on Hammerspoon exit.

Currently `products.lua` lists only `spaces`. Adding a future product is mechanical: drop a folder/symlink, add to the list.

### 2026-02-09: Modular zsh config

`.zsh/{core,aliases,functions,tools,prompt.zsh,netflix.zsh}`. Lazy-loaded NVM/SDKMAN. Auto-source loop picks up `.zsh/tools/*.zsh` (so the Spaces shim drops in without explicit sourcing).

## Patterns

For dotfiles-side patterns (zsh modules, lazy loading, host setup, ctx-lenses integration), see `systemPatterns.md` here.

For Spaces product patterns (architecture, async AppleScript, iTerm quirks, module conventions), see `~/spaces/hs-spaces/hs-spaces/main/memory_bank/systemPatterns.md`.

## Recent dotfiles-side activity

### 2026-05-10: Picked up accumulated machine + tooling config

Cleared a backlog of unstaged changes (`6350bf8`): `.gitconfig` Metatron auto-config + Netflix stash SSL certs + `push.autoSetupRemote`; `.zsh/aliases/claude.zsh` `cc`/`cr` shortcuts; `.zsh/tools/ctx.zsh` ctx-lenses sourcing (auto-picked by the `.zsh/tools/*.zsh` loop); `CLAUDE.md` repo-level deploy reminder.

Pushed to both remotes: `origin` (`github.com/nowucca/dotfiles2`) and `netflix` (`git.netflix.net/corp/satkinson-dotfiles`).

## Open items

- Nothing dotfiles-side. v1.6 Spaces work continues in the hs-spaces repo (per-space dashboard surfaces in the Spaces window).

## Quick references

- Hammerspoon product (Spaces): `~/spaces/hs-spaces/hs-spaces/main/` → `github.netflix.net/satkinson/hs-spaces`
- Spaces design history (kept here for archival): `docs/superpowers/{specs,plans}/`
- Branch: `main-zsh`. Pushed to both `origin` and `netflix` remotes; sync via `git push origin main-zsh && git push netflix main-zsh`.
- Dotfiles deploys to `~/` via `./bootstrap.sh -f` (rsync without `--delete` — see systemPatterns.md gotcha).
