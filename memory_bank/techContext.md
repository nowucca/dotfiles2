# Technical Context - Dotfiles

## Stack

- **macOS**, Apple Silicon. Hammerspoon 1.1.1 (verified `hs.processInfo.version`).
- **Zsh** primary shell. No oh-my-zsh — modular `.zsh/` for speed.
- **Lua 5.4** (Hammerspoon's embedded). Pure-Lua tests run via `hs -c "dofile(...)"`.
- **AppleScript** via `hs.osascript` (sync) or `hs.task` + `/usr/bin/osascript` (async).
- **JSON** via `hs.json` for product data.
- **Homebrew** for packages, **rsync** for dotfiles deploy.

## Sync workflow

```bash
cd ~/Work/dotfiles
./bootstrap.sh -f       # rsync repo to ~/, NO --delete
hs -c "hs.reload()"     # pick up Hammerspoon changes (full Lua state reload)
```

`bootstrap.sh` runs `rsync` without `--delete`. Removing a file from the repo doesn't remove it from `~/`. When deleting (e.g. retired Hammerspoon modules), explicitly `rm -rf ~/.hammerspoon/<dir>` after bootstrap.

## File map

```
~/Work/dotfiles/                        # source of truth
├── .zshrc, .zshenv, .tmux.conf
├── .zsh/{core,aliases,functions,tools,prompt.zsh,netflix.zsh}
├── .hammerspoon/
│   ├── init.lua                        # ~37-line host
│   ├── products.lua                    # product registry
│   └── spaces/                         # Spaces v1 product
│       ├── init.lua
│       ├── core/{config,log,data,iterm,chrome,agents}.lua
│       ├── ui/{menubar,switcher,banner,about}.lua
│       ├── actions/{labels,space-manager,profiles,launcher}.lua
│       └── test/{_helpers,run_all,test_*}.lua
├── docs/superpowers/{specs,plans}/
├── memory_bank/                        # this directory
└── bootstrap.sh

~/.hammerspoon/                         # runtime location
├── init.lua, products.lua, spaces/     # synced from repo
├── workspace-notes.json                # USER DATA — not in repo
├── space-profiles/                     # USER DATA — not in repo
└── Spoons/                             # Hammerspoon-managed
```

## Hammerspoon: AppleScript performance

**Synchronous AppleScript blocks the main thread.** `hs.osascript.applescript(script)` returns the result inline; while it runs the menubar, choosers, hotkeys, and timers are frozen. Cost scales with the number of macOS objects iterated.

**Measured cost** (the user's setup, ~10 iTerm windows, ~30 tabs):
- Get window IDs only: ~25ms (acceptable)
- Get per-tab `unique ID` + `name`: ~1.5s (UI freeze, unacceptable)
- Per-tab `is processing` adds another ~20% (drop unless needed)

**Use `hs.task` for async out-of-process execution:**

```lua
local task = require("hs.task")
task.new("/usr/bin/osascript", function(exit, stdout, stderr)
  -- callback fires on main thread when script finishes
  callback(parseRaw(stdout))
end, { "-e", APPLESCRIPT }):start()
-- main thread continues immediately; UI stays responsive
```

The pattern is documented in `systemPatterns.md`. Apply to anything iterating macOS collections.

## iTerm AppleScript quirks

iTerm2's scripting model differs from what's intuitive:

- **Tabs have no `id`** — address by 1-based **index**: `tab N of window id W`.
- **Sessions have stable `unique ID`** strings — use as the snapshot's tab identifier.
- **Session "title"** is `name of current session of t`, not `title of session of t`.
- **Window IDs** from iTerm AppleScript match `hs.spaces.windowSpaces(rawId)` for space attribution. Don't need `hs.window.get(id)` (which only returns Hammerspoon-tracked windows; Stage Manager hides some).
- **`set name`** sets the visible title momentarily, but iTerm's shell integration overwrites it on next prompt. The OSC title escape (`\033]0;...\007`) emitted from inside the shell is the persistent way to set a title.

## Hammerspoon: state caching across `hs -c`

Hammerspoon's Lua state persists across `hs -c` invocations and across `hs.reload()` discards-then-rebuilds. Test helpers like `_helpers.lua`'s counter persist via `package.loaded`. The test runner force-clears cached `_helpers`, `core.*`, `ui.*`, `actions.*` so edits land immediately:

```lua
for name in pairs(package.loaded) do
  if name:match("^test_") or name:match("^core%.")
     or name:match("^ui%.") or name:match("^actions%.") then
    package.loaded[name] = nil
  end
end
```

## Hammerspoon: window-event watchers are heavy

`hs.window.filter.new()` subscribes to **every window event in the system**. Avoid unless you specifically need window-focus changes — the spaces watcher and screen watcher cover most space-aware UI updates.

`hs.spaces.watcher` and `hs.screen.watcher` are cheap.

## Hammerspoon: space watchers fire before focus settles

When the user switches space (⌘⌃Space, ⌘+number), `hs.spaces.watcher` can fire while the focused window is still on the old space. Reading `hs.window.focusedWindow():screen()` immediately returns stale info. Defer space-watcher updates by ~200ms:

```lua
M._spaceWatcher = hs.spaces.watcher.new(function()
  hs.timer.doAfter(0.2, updateTitle)
end)
```

## Common commands

```bash
# Dotfiles
./bootstrap.sh -f               # sync repo to ~/

# Shell
time zsh -i -c exit             # benchmark startup (target < 100ms)

# Hammerspoon
hs -c "hs.reload()"             # reload (re-runs init.lua against fresh state)
hs -c "1+1"                     # responsiveness check
hs -c "_G.ws.spaces.agents.summary()"  # debug agent state
hs -c "dofile(hs.configdir .. '/spaces/test/run_all.lua')"  # tests

# Tmux
tmx [name]                      # attach or create session
tmdev [name]                    # 3-window dev layout
```

## Testing strategy

- **Pure functions** (parsers, formatters, data validation) → unit tests under `<product>/test/test_*.lua`. Run via `hs -c`.
- **Hammerspoon-coupled** (AppleScript, hs.* APIs) → manual smoke test from console with timing prints.
- **UI-coupled** (menubar, choosers, dialogs) → live human verification.

Always include a verify step in any plan that sets up the test path explicitly.

## Common debugging

| Symptom | Likely cause |
|---------|--------------|
| Menubar widget invisible | SF Symbol load failed AND title empty — ensure fallback glyph |
| Menu opens slowly | Synchronous AppleScript in build path — check for `iterm.snapshot()` calls |
| UI freezes periodically | Synchronous AppleScript polling — use `hs.task` async |
| `hs -c` hangs | Main thread blocked. `pkill -9 -f "hs -c"` and check for stuck `osascript` |
| Tests pick up old code | `package.loaded` cache stale — runner should clear `core/ui/actions` |
| `~/.hammerspoon/X` still there after deleting from repo | bootstrap doesn't `--delete`, must `rm` manually |

## Performance targets

- Shell startup: < 100ms
- `hs -c` round trip: < 50ms
- Menubar open: < 50ms (cached state)
- Agent state polling: 5s foreground / 30s background
- iTerm snapshot (async): no main-thread cost; off-process can take 1-2s
