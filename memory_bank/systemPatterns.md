# System Patterns — Dotfiles

## Repo layout

```
~/Work/dotfiles/
├── .zshrc, .zshenv, .tmux.conf
├── .zsh/                        # modular zsh config
│   ├── core/                    # options, path, history, completions
│   ├── aliases/                 # nav, general, macos, dev, git, hammerspoon, tmux
│   ├── functions/               # utils, network
│   ├── tools/                   # z, nvm, sdkman (lazy), ctx, spaces (symlink)
│   ├── prompt.zsh, netflix.zsh
├── .hammerspoon/
│   ├── init.lua                 # ~37-line host
│   ├── products.lua             # `return { "spaces" }`
│   └── spaces -> ~/spaces/hs-spaces/.../hammerspoon/spaces  (symlink)
├── docs/superpowers/{specs,plans}/    # design history (Spaces v1)
├── memory_bank/                 # this directory
├── bin/, brew.sh, install.sh
└── bootstrap.sh                 # rsyncs repo to ~/, NO --delete
```

## Hammerspoon host (in this repo)

The host is intentionally tiny:

```lua
require("hs.ipc")
package.path = hs.configdir .. "/?/init.lua;" .. hs.configdir .. "/?.lua;" .. package.path

local productNames = require("products")
for _, name in ipairs(productNames) do
  package.path = hs.configdir .. "/" .. name .. "/?.lua;"
              .. hs.configdir .. "/" .. name .. "/?/init.lua;"
              .. package.path
end

local loaded = {}
for _, name in ipairs(productNames) do
  local ok, mod = pcall(require, name)
  if ok and mod and type(mod.start) == "function" then
    mod.start()
    table.insert(loaded, mod)
  end
end

hs.shutdownCallback = function()
  for _, mod in ipairs(loaded) do
    if type(mod.stop) == "function" then pcall(mod.stop) end
  end
end
```

Products provide `start()` / `stop()`. Each product's internal `require("core.foo")` resolves because `package.path` is extended with `<product>/?.lua` for every registered product.

Currently `products.lua` registers only `spaces`.

For everything inside the Spaces product (architecture, modules, the async AppleScript pattern, iTerm quirks), see `~/spaces/hs-spaces/hs-spaces/main/memory_bank/`.

## Symlinks for products

Products live in their own repos under `~/spaces/`. Dotfiles symlinks them in:

```
.hammerspoon/spaces -> /Users/satkinson/spaces/hs-spaces/hs-spaces/main/hammerspoon/spaces
.zsh/tools/spaces.zsh -> /Users/satkinson/spaces/hs-spaces/hs-spaces/main/shell/spaces.zsh
```

`bootstrap.sh` uses `rsync -avhq --no-perms` — `-a` includes `-l`, which preserves symlinks rather than dereferencing them. So `~/.hammerspoon/spaces` ends up as a symlink to the absolute path of the product repo.

**Gotcha:** rsync without `--delete` won't replace a directory with a symlink. The first time a directory becomes a symlink in the repo, you must `rm -rf` the runtime location before `bootstrap.sh -f`:

```bash
rm -rf ~/.hammerspoon/spaces ~/.zsh/tools/spaces.zsh
./bootstrap.sh -f
```

After that one-time cleanup, bootstrap is idempotent.

## Zsh module pattern

```zsh
#!/usr/bin/env zsh
# .zsh/aliases/mytopic.zsh

is_mac || return 0   # platform guard

alias myalias='mycommand'

function myfunction() {
  # ...
}
```

`.zshrc` sources these in a fixed order; topics are auto-loaded via globbing. Any file matching `~/.zsh/tools/*.zsh` is auto-sourced — that's how the Spaces shim (a symlink) gets picked up without an explicit source line in `.zshrc`.

## Lazy loading

Slow tools wrap their entry-point function. First call replaces the wrapper:

```zsh
nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm "$@"
}
```

NVM saves ~1000ms; SDKMAN saves ~400ms.

## Fast git prompt

`.zsh/prompt.zsh` skips dirty checks for repos with `.git` over 100MB; shows `⚡` instead of `+!?$`. Big monorepos load quickly.

## Hardcoded paths

Avoid `eval $(... shellenv)` in startup:

```zsh
export HOMEBREW_PREFIX="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
```

## ctx-lenses integration

`.zsh/tools/ctx.zsh` is a one-liner that runs `ctx-lenses setup zsh` at shell startup. Provides `ctx`/`c` aliases and the `__ctx_ps1` prompt helper. The binary lives in `~/spaces/nflx-side/ctx/main/.venv/bin/ctx-lenses` — but the shell function reads `$CTX_BIN`, which is set by `ctx-lenses setup zsh`'s output.

Spaces (the product) was set up as a ctx-lenses space at `~/spaces/hs-spaces/`.

## Tmux

- Prefix `Ctrl+A` (screen-style)
- Splits `|` and `-` (stay in current path)
- Pane navigation: `hjkl` (vim-style)
- Window switching: `Alt+1-9` (no prefix)
- Mouse + pbcopy
- Solarized

Aliases (`.zsh/aliases/tmux.zsh`): `tmx`, `tmdev`, `tmkill`, `tmls`.

## Apply changes

```bash
cd ~/Work/dotfiles
./bootstrap.sh -f       # rsync repo to ~/
hs -c "hs.reload()"     # pick up Hammerspoon changes
time zsh -i -c exit     # benchmark shell startup
```
