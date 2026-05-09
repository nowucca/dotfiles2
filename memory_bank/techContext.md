# Technical Context — Dotfiles

## Stack

- **macOS**, Apple Silicon. Hammerspoon 1.1.1.
- **Zsh** primary shell. No oh-my-zsh — modular `.zsh/` for speed.
- **tmux** with screen-style `Ctrl+A` prefix.
- **Lua 5.4** (Hammerspoon's embedded) for products under `.hammerspoon/`.
- **Homebrew** for packages, **rsync** for dotfiles deploy.

For Spaces product technical detail (Hammerspoon API, AppleScript performance, iTerm quirks, etc.), see `~/spaces/hs-spaces/hs-spaces/main/memory_bank/techContext.md`.

## Sync workflow

```bash
cd ~/Work/dotfiles
./bootstrap.sh -f       # rsync repo to ~/, NO --delete
hs -c "hs.reload()"     # pick up Hammerspoon changes
```

`bootstrap.sh` uses `rsync -avhq --no-perms` — `-a` includes `-l` (preserves symlinks, doesn't dereference). Removing a file from the repo does NOT remove it from `~/`. When deleting (e.g. retired host file) or replacing a directory with a symlink, explicitly `rm -rf ~/...` first.

## File map

```
~/Work/dotfiles/                        # source of truth
├── .zshrc, .zshenv, .tmux.conf
├── .zsh/{core,aliases,functions,tools,prompt.zsh,netflix.zsh}
├── .hammerspoon/
│   ├── init.lua                        # ~37-line host
│   ├── products.lua                    # `return { "spaces" }`
│   └── spaces -> ~/spaces/hs-spaces/.../hammerspoon/spaces  (symlink)
├── docs/superpowers/{specs,plans}/     # design history
├── memory_bank/                        # this directory
└── bootstrap.sh

~/.hammerspoon/                         # runtime (synced from repo)
├── init.lua, products.lua              # synced
├── spaces                              # symlink (preserved by rsync -al)
├── workspace-notes.json                # USER DATA — not in repo
├── space-profiles/                     # USER DATA — not in repo
└── Spoons/                             # Hammerspoon-managed
```

## Common commands

```bash
# Shell
time zsh -i -c exit     # benchmark startup (target < 100ms)
./bootstrap.sh -f       # sync dotfiles

# Hammerspoon
hs -c "hs.reload()"             # reload (re-runs init.lua against Lua state)
hs -c "1+1"                     # responsiveness check
hs -c "_G.ws.spaces.config.brand.version"  # confirm Spaces product loaded

# tmux
tmx [name]              # attach or create session
tmdev [name]            # 3-window dev layout
tmkill                  # interactive session killer
```

## Common debugging

| Symptom | Likely cause |
|---------|--------------|
| Shell startup slow | Non-lazy tool init. `time zsh -i -c exit` then `zprof` to profile |
| Aliases missing | Run `./bootstrap.sh -f` or open a new terminal |
| `hs -c` hangs | Hammerspoon main thread blocked. `pkill -9 -f "hs -c"` and check Console |
| `~/.hammerspoon/<dir>` lingers after deleting from repo | bootstrap doesn't `--delete`. `rm -rf` manually |
| Symlink replaced by real dir after bootstrap | bootstrap created a real dir before the symlink existed in the repo. `rm -rf ~/.hammerspoon/<dir>` then bootstrap |

## Performance targets

- Shell startup: < 100ms
- `hs -c` round trip: < 50ms

## ctx-lenses

Shell integration sourced from `.zsh/tools/ctx.zsh`. The binary lives in `~/spaces/nflx-side/ctx/main/.venv/bin/ctx-lenses`. Used to:

- Register spaces (`ctx space add hs-spaces ~/spaces/hs-spaces`)
- Scaffold worktree-style layouts under `~/spaces/`
- Switch between spaces interactively (`ctx switch`)

Spaces are organised as `~/spaces/<space>/<repo>/<branch>` worktrees.
