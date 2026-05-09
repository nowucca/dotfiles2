# System Patterns - Dotfiles

## Repo layout

```
~/Work/dotfiles/
├── .zshrc, .zshenv, .tmux.conf
├── .zsh/                       # modular zsh config
│   ├── core/                   # options, path, history, completions
│   ├── aliases/                # nav, general, macos, dev, git, hammerspoon, tmux
│   ├── functions/              # utils, network
│   ├── tools/                  # z, nvm, sdkman (lazy loaded), ctx, spaces
│   ├── prompt.zsh, netflix.zsh
├── .hammerspoon/               # Hammerspoon host + products (see below)
├── docs/superpowers/{specs,plans}/
├── memory_bank/                # this directory
├── bin/                        # utility scripts
└── bootstrap.sh                # rsyncs repo to ~/ (no --delete)
```

## Hammerspoon host + products

Multi-product layout. `init.lua` is a thin host (~37 lines) that loads each product listed in `products.lua` and calls its `start()`. `hs.shutdownCallback` calls each product's `stop()` on exit.

```
~/.hammerspoon/
├── init.lua             # host
├── products.lua         # `return { "spaces" }`
└── spaces/              # the Spaces product
    ├── init.lua         # start/stop, hotkey registration, ws.spaces namespace
    ├── core/            # config, log, data, iterm, chrome, agents
    ├── ui/              # menubar, switcher, banner, about
    ├── actions/         # labels, space-manager, profiles, launcher
    └── test/            # _helpers, run_all, test_*.lua
```

Each product owns its own menubar widget and watcher lifecycle. Adding a new product: drop a folder under `.hammerspoon/`, add the name to `products.lua`, ensure the module exports `start()`/`stop()`.

## Async AppleScript pattern (load-bearing)

**Why:** `hs.osascript.applescript(script)` runs synchronously on Hammerspoon's main thread. While it's running the menubar, choosers, hotkeys, and timers are all frozen. Querying many iTerm objects (10 windows × 30 tabs ≈ 1500 property lookups) easily takes 1–2 seconds. Polling at that cost makes UI feel broken.

**The pattern:**

```lua
local task = require("hs.task")

local function snapshotAsync(callback)
  local function done(exitCode, stdout, stderr)
    if exitCode ~= 0 then
      log.warn("snapshot failed: " .. (stderr or ""))
      callback({})
      return
    end
    callback(parseRaw(stdout))
  end
  task.new("/usr/bin/osascript", done, { "-e", APPLESCRIPT }):start()
end
```

`hs.task` runs `osascript` in a separate process. The Lua main thread doesn't block — UI stays responsive while the script runs. The callback fires on the main thread when the task completes.

**When to apply:** any AppleScript that iterates collections of macOS objects (windows, tabs, mail messages, finder items). Anything that takes more than ~50ms is worth moving off the main thread.

**Verify with timing:**

```lua
local t0 = hs.timer.absoluteTime()
fn()
print(string.format("%.1f ms", (hs.timer.absoluteTime() - t0) / 1e6))
```

Compare sync vs async; the async version's call should return in <5ms regardless of script duration.

**Sync still has its place:** smoke tests, console debugging, one-off ad-hoc calls where you need the result inline. Keep both; agents.lua-style polling uses the async path, smoke tests use the sync path.

## Spaces product patterns

### Tab-title state convention

Agents announce state via OSC title escape:

```
\033]0;[spaces:STATE] FREEFORM\007
```

`STATE ∈ {idle, run, wait, done, err}`. Tabs without the prefix render as `idle`. The shell shim is `~/.zsh/tools/spaces.zsh`; auto-sourced by the existing `~/.zsh/tools/*.zsh` loop in `.zshrc`. Usage:

```zsh
spaces_state run "task name"
spaces_state done
```

`core/agents.lua` parses titles via regex `^%[spaces:(%a+)%]%s*(.*)$`. Unknown state names fall back to `idle` with raw title preserved.

### Cached state map drives the menubar

The menubar is opened on every click — Hammerspoon calls the `setMenu(buildMenu)` function each time. **Never** call `iterm.snapshot()` or any synchronous AppleScript from the menu build path. Build from cached agent state (`agents.forSpace(sid)`), refreshed by the polling timer.

The cached record carries everything the menubar needs:

```lua
{ spaceId, winId, tabId, tabIndex, state, title, changedAt }
```

`tabIndex` is what `iterm.focusTab(winId, idx)` needs (AppleScript addresses tabs by 1-based index, not by id).

### Lifecycle and watchers

Each product's `start()` creates watchers, hotkeys, the menubar widget. `stop()` tears them down. The host calls `stop()` on `hs.shutdownCallback`. On `hs.reload()` the Lua state is discarded and `init.lua` re-runs from scratch — no leak.

`hs.window.filter.new()` watches every window event in the system; it's heavy. Avoid unless you actually need window-focus events. The Spaces menubar uses only the spaces watcher and screen watcher.

## Module conventions

- One `local M = {}` ... `return M` per file. No globals.
- Test-only API gets an underscore prefix (`M._refreshFromSnapshot`, `M._setWriter`).
- Heavy or platform-specific imports lazy-loaded inside functions to keep tests runnable without iTerm/Hammerspoon.
- Tests live in `<product>/test/test_*.lua`. Run with `hs -c "dofile(hs.configdir .. '/<product>/test/run_all.lua')"`. The runner force-clears cached `core/ui/actions` modules so edits land immediately.

## Zsh patterns (still current)

### Lazy loading

```zsh
nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm "$@"
}
```

### Fast prompt for huge repos

`.zsh/prompt.zsh` skips dirty checks for repos with `.git` over 100MB; shows `⚡` instead of `+!?$`.

### Hardcoded paths over `eval $(... shellenv)`

```zsh
export HOMEBREW_PREFIX="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
```

## Apply changes

```bash
cd ~/Work/dotfiles
./bootstrap.sh -f       # rsync to ~/, no --delete
hs -c "hs.reload()"     # pick up Hammerspoon changes
```

Bootstrap doesn't delete files in `~/` that aren't in the repo — when removing a file from the repo, also `rm -rf ~/.hammerspoon/<dir>` or equivalent.
