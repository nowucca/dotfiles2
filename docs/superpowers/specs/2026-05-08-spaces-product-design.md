# Spaces — Hammerspoon-hosted desktop product for agent-driven work

**Date:** 2026-05-08
**Status:** Design approved, pending implementation plan
**Repo:** `~/Work/dotfiles`, files under `.hammerspoon/`
**Sync:** `./bootstrap.sh -f` from repo root

## Why

The existing `.hammerspoon/` config is a useful but unbranded toolkit for managing macOS Spaces — labels, profiles, app launchers. The goal is to evolve it into a deliberately-branded macOS-native shell for running long-running AI agents (Claude Code, others) without an IDE in the loop. The desktop becomes the operator surface: a glance at the menubar tells you which agents are running, where, and in what state. Future products can plug into the same Hammerspoon host.

## Product identity

- **Name:** Spaces.
- **Glyph:** SF Symbol `square.stack.3d.up.fill`, rendered as a template image so it tracks the system menubar tint and dark-mode state. (Hammerspoon 1.1.1 supports `hs.image.imageFromName("symbol://...")`.)
- **Voice:** workmanlike. Terse, factual, no emoji, no exclamation marks. Status messages state what happened: `Spinnaker ready`, `Closed Spinnaker · 4 windows`, `No active space`. Console banner on load: `Spaces 1.0.0 ready · 6 spaces tracked · 0 agents`.
- **Alert style:** centralised in `core/config.lua` — text `#e6e6e6`, fill `rgba(0,0,0,0.78)`, radius 6, no stroke. All product alerts share this.

## Scope

### v1 (this design)

1. **Branding polish** — name, glyph, voice, About dialog, version, quiet logging, central alert style.
2. **Agent run tracking** — per-tab agent state surfaced in the menubar, derived from a tab-title convention.
3. **Agent launchers** — two fixed actions: "New agent space…" and "New agent tab here".
4. **Code reorganisation** — replace the flat `modules/` folder with a `spaces/` product folder under `.hammerspoon/`, with a small product-host `init.lua` that can later load additional products.

### v1.5 (deferred, named for traceability)

- **Extract to its own repo** — `spaces-hs` (working name) hosting the Lua product. Dotfiles `.hammerspoon/spaces` becomes a thin pointer (symlink during dev, eventually a release tag pulled via the install script).
- **Manuals v2 site** — a `manual/` folder in the new repo, mirroring the Netflix manuals v2 format, covering install, the tab-title state convention, the shell shim, troubleshooting.
- **Installable Claude skill** — a `.claude/skills/spaces.md` (or plugin) shipped from the same repo. Triggers on Hammerspoon/Spaces-related tasks: knows the architecture, the state convention, the hotkey set, and the conventions for adding new actions.
- **Install script** — `install.sh` in the new repo: clones to a known path, symlinks `~/.hammerspoon/spaces`, sources `spaces.zsh`. Same script handles upgrades.

### v2 (deferred, named for traceability)

- **Agent notifications** — native banners on state transitions (`run → done`, `run → wait`, `run → err`). Click switches space and focuses the specific iTerm tab.
- **Templated launchers** — user-editable templates for repeatable agent setups.
- iTerm side-panel/status-bar integration; Sourcegraph/Slack/JIRA hooks; agent activity export.

## Architecture

### Layout

```
.hammerspoon/
├── init.lua                    # ~25 lines: load product registry, init each
├── products.lua                # `return { "spaces" }`
├── spaces/                     # the Spaces product
│   ├── init.lua                # product entry: name, version, start(), stop()
│   ├── core/
│   │   ├── log.lua             # leveled logging, log.try() pcall wrapper
│   │   ├── config.lua          # brand const, poll intervals, paths, alert style
│   │   ├── data.lua            # JSON persistence (moved from modules/data.lua)
│   │   ├── iterm.lua           # single AppleScript surface for iTerm
│   │   ├── chrome.lua          # Chrome-specific window helpers
│   │   └── agents.lua          # title parsing + per-tab state map
│   ├── ui/
│   │   ├── menubar.lua         # nested Space → Window → Tab
│   │   ├── switcher.lua        # space chooser
│   │   ├── banner.lua          # label banner display
│   │   └── about.lua           # About Spaces dialog
│   └── actions/
│       ├── labels.lua          # set/clear/prune label data
│       ├── space-manager.lua   # create/close space
│       ├── launcher.lua        # Chrome, iTerm, new agent space, new agent tab
│       └── profiles.lua        # save/restore (existing, cleaned)
└── (no modules/ folder — old layout deleted in this change)
```

Future products live as siblings to `spaces/` and are added to `products.lua`. Each product owns its own menubar widget and lifecycle.

### Lifecycle

- Host `init.lua` requires `products.lua`, then for each product calls `require(<product>).start()`.
- On Hammerspoon reload, host calls `stop()` on each product before `start()` — this fixes the watcher leak in the current code, where `hs.spaces.watcher`, `hs.screen.watcher`, and `hs.window.filter` instances accumulate across reloads.
- Each product's `stop()` deletes its menubar widget, stops timers, and unsubscribes watchers.
- The host exposes a global `ws` table for Hammerspoon-console debugging (preserves existing muscle memory). v1 populates `ws.spaces` with the product's public modules: `ws.spaces.iterm`, `ws.spaces.agents`, `ws.spaces.menubar`, `ws.spaces.labels`, `ws.spaces.switcher`, `ws.spaces.profiles`, `ws.spaces.manager`, `ws.spaces.launcher`. The flat `ws.labels`, `ws.switcher`, etc. shortcuts from today's `init.lua` are removed; `ws.spaces.<name>` replaces them.

## Tab-title state convention

Agents announce state by writing the OS-level title via OSC 0/2:

```
\e]0;[spaces:STATE] FREEFORM\a
```

- Namespace `spaces:` so it doesn't collide with whatever else writes the title.
- `STATE ∈ {idle, run, wait, done, err}`.
  - `run` — actively working
  - `wait` — awaiting input (user judgement, MCP confirmation, etc.)
  - `done` — finished, exit 0
  - `err` — finished non-zero or self-reported error
  - `idle` — explicitly idle (rare; usually you just don't set the title)
- `FREEFORM` is the human-readable subject, displayed verbatim (task name, branch, ticket).
- Tabs without the prefix are shown as `(shell)` with no badge.

### Shell shim

Ships in the dotfiles repo at `.zsh/tools/spaces.zsh`, sourced from `.zshrc`:

```zsh
spaces_state() {
  local state="${1:-idle}"
  local title="${2:-}"
  printf '\033]0;[spaces:%s] %s\007' "$state" "$title"
}
```

Agent hooks call `spaces_state run "task name"` / `spaces_state done` etc. Humans can call it manually. The shim has zero dependencies and is safe outside iTerm (the escape is harmless if no terminal interprets it).

### State badges in the menubar

| State  | Glyph | Meaning |
|--------|-------|---------|
| `run`  | `●`   | Working |
| `wait` | `◐`   | Awaiting input |
| `done` | `○`   | Finished |
| `err`  | `✕`   | Error |
| `idle` | (none) | Plain shell |

## Components

### `core/iterm.lua` — single AppleScript surface

Today, AppleScript calls and window-find loops are sprinkled across `app-launcher.lua`, `space-manager.lua`, and `profiles.lua`, with five overlapping `findAndMoveNewWindow*` variants. All of that funnels through `core/iterm.lua`. Public API:

```lua
iterm.snapshot()
  -- { windows = { { id, screen, space, tabs = { {id, title, isProcessing}, ... } } } }
iterm.newWindow(opts)        -- returns winId. opts: { profile, cwd, command, title }
iterm.newTab(winId, opts)    -- returns tabId. same opts shape
iterm.focusTab(winId, tabId) -- switches space if needed, then focuses
iterm.setTabTitle(winId, tabId, text)
```

Internally, one AppleScript helper takes a request string and returns a parsed Lua table — no ad-hoc `osascript` outside this module. This is the chunk of work that retires the duplicated launcher loops.

### `core/chrome.lua`

Mirrors the Chrome-specific patterns from today's `app-launcher.lua`: `chrome.openWindowOnSpace(spaceId, screen)`. Same two-phase pattern (AppleScript `make new window`, then locate-and-move with Stage Manager workaround). Pulled out so the iTerm and Chrome paths don't share a 700-line file.

### `core/agents.lua` — title parsing + state map

Sole consumer of `iterm.snapshot()`. Maintains an in-memory map keyed by `(spaceId, windowId, tabId)`:

```lua
{ state = "run"|"wait"|"done"|"err"|"idle", title = "...", changedAt = <ts> }
```

- Parser: single regex `^%[spaces:(%a+)%]%s*(.*)$`. Non-matches become `state = "idle"` with `title = <raw tab title>`.
- State transitions fire `agents.onChange(prev, next)`. The menubar subscribes.
- Polling owned here. Foreground (Hammerspoon or iTerm frontmost): 2s. Background: 10s. Driven by `hs.application.watcher`. Plus event-driven refresh on iTerm window-focus change.
- `agents.summary()` returns `{ run = N, wait = N, done = N, err = N }` for the menubar dot suffix and About dialog.

### `core/log.lua`

`log.info / debug / warn / error` with a `level` setting from `core/config.lua` (default `info`). Replaces every `print(...)` in the existing modules:

- Status changes → `info`
- AppleScript chatter, timer ticks → `debug`
- Recoverable failures → `warn`
- Should-not-happen → `error`

Also exposes `log.try(fn, ctx)` — a `pcall` wrapper that logs `error` with `ctx` on failure. Replaces `safeCall` from today's `space-manager.lua`. Standardises error handling product-wide.

### `core/config.lua`

```lua
return {
  brand = { name = "Spaces", version = "1.0.0", glyph = "square.stack.3d.up.fill" },
  paths = {
    data = hs.configdir .. "/workspace-notes.json",
    profiles = hs.configdir .. "/space-profiles",
  },
  poll = { foregroundSec = 2, backgroundSec = 10 },
  alert = { textColor = {hex="#e6e6e6"}, fillColor = {alpha=0.78}, radius = 6, strokeWidth = 0 },
  log = { level = "info" },
}
```

Tunable in one place. The 2s/10s polling cadence is a guess; if it turns out to be too aggressive or invisible, change one number.

### `core/data.lua`

Moves verbatim from `modules/data.lua`. New field `agentCwds` (array of strings, capped at 10) backs the cwd recents chooser used by the agent launchers.

### `ui/menubar.lua`

Built fresh on each open via `:setMenu(buildMenu)` so no separate cache invalidation. Shape:

```
▤ Spinnaker ●                  (widget title — current space + agent dot)

▶ Spinnaker (current)
  ▶ iTerm — Window 1
      ● orca:fix-flake
      ◐ keel:review
        shell
  ▶ iTerm — Window 2
      ○ done: deploy-check
   Dotfiles
   Personal
─────────────
  New agent space…           ⌘⌃A
  New agent tab here         ⌘⌃⇧A
─────────────
  Set Label…                 ⌘⌃⇧L
  New Space                  ⌘⌃⇧N
  Close Space                ⌘⌃⇧C
─────────────
  Profiles                   ▸
  Manage Labels              ▸
─────────────
  About Spaces…
```

Behaviour:

- **Top section:** every space on the current screen. Current space is expanded inline (its windows/tabs visible); other spaces collapse to a click-to-switch row. Avoids a 30-deep menu.
- **Tab rows:** clicking calls `iterm.focusTab(winId, tabId)` — switches space if needed, focuses the tab. Same primitive the v2 click-to-focus notification will reuse.
- **Widget title:** `<glyph>` alone if no label; `<glyph> Spinnaker` if labelled; `<glyph> Spinnaker ●` if a `run`-state agent is on the current space (filled = run, hollow = wait, no dot otherwise). Reflects only the current space — keeps the bar quiet when other spaces have agents you're not actively watching.
- **Profiles / Manage Labels:** existing submenus, contents unchanged.

### `ui/about.lua`

`hs.dialog.alert` triggered by the bottom menu item:

```
Spaces 1.0.0
Built 2026-05-08

Config: ~/.hammerspoon/spaces
Data:   ~/.hammerspoon/workspace-notes.json
Profiles: ~/.hammerspoon/space-profiles (3 saved)

6 spaces tracked
0 agents (run: 0  wait: 0  done: 0  err: 0)
```

Single OK button. Useful for support and proves the thing is a real product, not a script.

### `ui/banner.lua` and `ui/switcher.lua`

`banner.show()` is what `space-labels.show()` is today (alert with current label). `switcher.show()` is what `space-switcher.show()` is today (chooser of all spaces on current screen). Behaviour unchanged; just relocated and renamed for the new layout.

### `actions/launcher.lua` — four actions, one path

All four share `core/iterm.lua` and `core/chrome.lua`, killing the five overlapping `findAndMoveNewWindow*` variants in today's `app-launcher.lua`.

- `launcher.openChrome()` — current behaviour, via `chrome.openWindowOnSpace(...)`.
- `launcher.openITerm()` — current behaviour, via `iterm.newWindow({ cwd = home })`.
- `launcher.newAgentSpace()` —
  1. Prompt for label (default empty).
  2. Create new space on current screen via `actions/space-manager.createNewSpace`.
  3. Apply label.
  4. Pick cwd via `hs.chooser` from the recents list in `agentCwds` (with a "Choose other…" entry that opens `hs.dialog.chooseFolder`).
  5. `iterm.newWindow({ cwd = chosen, command = "claude", title = "[spaces:idle] " .. label })`.
  6. Update `agentCwds` recents (move-to-front, cap 10).
- `launcher.newAgentTabHere()` —
  - If an iTerm window exists on the current space, `iterm.newTab(winId, opts)`.
  - Otherwise, `iterm.newWindow(opts)`.
  - Otherwise identical to `newAgentSpace` from step 4 onward (cwd chooser, command, initial title).

The cwd chooser and recents list are not glamorous but are the difference between "I'll set this up later" and "I use it ten times a day."

### `actions/space-manager.lua` and `actions/labels.lua` and `actions/profiles.lua`

Behaviour unchanged from the existing `space-manager.lua`, `space-labels.lua` (data ops only — banner moves to `ui/banner.lua`), and `profiles.lua`. Internal AppleScript and window-find code routes through `core/iterm.lua` / `core/chrome.lua` instead of inlining its own. Logging routes through `core/log.lua`.

## Hotkeys

Two new bindings; existing bindings unchanged so muscle memory carries.

| Hotkey      | Action                       | Status |
|-------------|------------------------------|--------|
| `⌘⌃A`       | New agent space…             | New |
| `⌘⌃⇧A`      | New agent tab here           | New |
| `⌘⌃L`       | Show label banner            | Existing |
| `⌘⌃⇧L`      | Set label                    | Existing |
| `⌘⌃Space`   | Switch space                 | Existing |
| `⌘⌃N`       | App chooser                  | Existing |
| `⌘⌃⇧N`      | New space                    | Existing |
| `⌘⌃⇧C`      | Close space                  | Existing |
| `⌘⌃B`       | Open Chrome                  | Existing |
| `⌘⌃T`       | Open iTerm                   | Existing |
| `⌘⌃S`       | Save profile                 | Existing |
| `⌘⌃R`       | Restore profile              | Existing |

`⌘⌃A` / `⌘⌃⇧A` are unbound in macOS by default and pair with the `A`-as-agent mnemonic.

## Migration

| Today (`modules/`)        | New home (`spaces/`)              | Notes |
|---------------------------|-----------------------------------|-------|
| `data.lua`                | `core/data.lua`                   | unchanged + `agentCwds` field |
| `space-labels.lua`        | `actions/labels.lua` + `ui/banner.lua` | data ops vs. UI banner split |
| `space-switcher.lua`      | `ui/switcher.lua`                 | unchanged |
| `space-manager.lua`       | `actions/space-manager.lua`       | window-move loops extracted |
| `profiles.lua`            | `actions/profiles.lua`            | AppleScript routed through `core/iterm.lua` |
| `app-launcher.lua`        | `actions/launcher.lua` + `core/iterm.lua` + `core/chrome.lua` | 5 duplicate find-loops collapsed to 1 |
| `menubar.lua`             | `ui/menubar.lua`                  | rewritten for nested layout, brand, summary |
| (none)                    | `core/log.lua`, `core/config.lua`, `core/agents.lua`, `core/iterm.lua`, `core/chrome.lua`, `ui/about.lua`, `spaces/init.lua` | new |
| `init.lua` (host)         | `init.lua` (host) + `products.lua`| trimmed to ~25 lines |
| (dotfiles repo)           | `.zsh/tools/spaces.zsh`           | shell shim, sourced from `.zshrc` |

The old `.hammerspoon/modules/` folder is **deleted** in the same change. No transitional path. `bootstrap.sh -f` syncs the new tree to `~/`.

User data preserved (paths unchanged):

- `~/.hammerspoon/workspace-notes.json` — labels and space mappings
- `~/.hammerspoon/space-profiles/*.json` — saved profiles

## Risks and mitigations

- **iTerm AppleScript quirks around tab IDs across new windows.** `core/iterm.lua` handles defensively (tab IDs may not exist immediately after window creation). A debug helper `ws.iterm.dump()` callable from the Hammerspoon console prints the current snapshot for inspection.
- **SF Symbol image rendering.** Hammerspoon 1.1.1 (confirmed installed) and macOS 11+ support `imageFromName("symbol://...")`. Fallback path: ship a 22×22 PDF/PNG asset under `spaces/assets/glyph.pdf` and use `imageFromPath` if the symbol load returns nil. Detection happens once at startup and is logged.
- **2s polling cost.** AppleScript round-trip for "list titles of all tabs" is a handful of milliseconds; should be invisible. `core/config.lua` keeps the interval tunable for the rare case where it isn't.
- **Existing watchers leak across Hammerspoon reloads.** Already a bug in today's code; `start()`/`stop()` lifecycle in the new design fixes it.
- **Stage Manager hides new windows from `app:allWindows()`.** Existing code has a `focusedWindow()` workaround; that workaround moves into `core/iterm.lua` so the new launchers inherit it.

## Out of scope

- Agent notifications (v2).
- Templated launchers (v2).
- iTerm-side status bar / coloured tab badges.
- Sourcegraph/Slack/JIRA integrations from the menubar.
- Export of agent activity logs.
- Multi-machine sync of labels/profiles.

## Acceptance criteria

The implementation is done when:

1. `./bootstrap.sh -f` syncs the new tree and Hammerspoon reloads cleanly with no errors in the console.
2. The menubar shows `▤` (or `▤ <label>` when on a labelled space), responds to clicks with the nested layout, switches spaces correctly, and click-to-focus on a tab row works.
3. With `spaces_state run "test"` set in an iTerm tab, the menubar shows that tab with a `●` badge within 2 seconds.
4. `⌘⌃A` creates a new labelled space with a single iTerm tab running `claude` in a chosen cwd.
5. `⌘⌃⇧A` adds a new tab to the current iTerm window on the current space, also running `claude`.
6. `About Spaces…` opens a dialog with the version, paths, and live agent counts.
7. The Hammerspoon console during normal use is quiet at default log level (no `print()` chatter).
8. `~/.hammerspoon/modules/` no longer exists; `~/.hammerspoon/spaces/` does.
9. Existing `workspace-notes.json` and `space-profiles/*.json` are unchanged and still readable.
10. Existing hotkeys (`⌘⌃L`, `⌘⌃Space`, `⌘⌃B`, `⌘⌃T`, `⌘⌃S`, `⌘⌃R`, `⌘⌃⇧L`, `⌘⌃⇧N`, `⌘⌃⇧C`) all behave identically to today.
