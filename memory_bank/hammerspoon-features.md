# Hammerspoon — Spaces product feature reference

Quick reference for the Spaces v1 product (`.hammerspoon/spaces/`). For architecture see `systemPatterns.md`; for current state see `activeContext.md`.

## Hotkeys

| Hotkey | Action |
|--------|--------|
| `⌘⌃A` | **New agent space** — prompt label + cwd, create space, launch iTerm with `claude` |
| `⌘⌃⇧A` | **New agent tab here** — pick cwd, add tab to current iTerm window with `claude` |
| `⌘⌃L` | Show current space's label as banner |
| `⌘⌃⇧L` | Set or update current space's label |
| `⌘⌃Space` | Open space switcher chooser |
| `⌘⌃N` | App launcher chooser (Chrome / iTerm) |
| `⌘⌃B` | Open Chrome on current space |
| `⌘⌃T` | Open iTerm on current space |
| `⌘⌃S` | Save current space as profile |
| `⌘⌃R` | Restore profile to current space |
| `⌘⌃⇧N` | Create new space (labelled, with iTerm + Chrome) |
| `⌘⌃⇧C` | Close current space (with confirmation) |

## Tab-title state convention

Agents announce state by writing the OS title via OSC 0/2:

```
\033]0;[spaces:STATE] FREEFORM\007
```

States: `idle`, `run`, `wait`, `done`, `err`. Tabs without the prefix render as `idle`.

Shell shim auto-loaded from `~/.zsh/tools/spaces.zsh`:

```zsh
spaces_state run "task name"
spaces_state wait
spaces_state done
spaces_state err
```

## Menubar layout

Widget title: SF Symbol icon (when available) + current space's label + dot badge if running/waiting agent on this space. Without the SF Symbol, falls back to a `▤` text glyph.

Click opens:

```
▶ <current space>  (current)            ← inline-expanded
   ▶ iTerm — Window 1
       ● task title
       ◐ another task
         shell
   ▶ iTerm — Window 2
       ○ done: deploy-check
   <other space>                        ← click to switch
   <other space>
─────
New agent space…           ⌘⌃A
New agent tab here         ⌘⌃⇧A
─────
Set Label…                 ⌘⌃⇧L
New Space                  ⌘⌃⇧N
Close Space                ⌘⌃⇧C
─────
Open Chrome                ⌘⌃B
Open iTerm                 ⌘⌃T
─────
Profiles ▸
Manage Labels ▸
─────
About Spaces…
```

State badges in tab rows:

| State | Glyph |
|-------|-------|
| `run` | `●` |
| `wait` | `◐` |
| `done` | `○` |
| `err` | `✕` |
| `idle` / shell | `·` |

Click a tab row → switches to its space + focuses that tab via iTerm AppleScript.

## Console debug namespace

```lua
_G.ws.spaces.config        -- brand, paths, poll cadence
_G.ws.spaces.log           -- log.info/debug/warn/error/try
_G.ws.spaces.agents        -- summary(), forSpace(sid), get(s,w,t)
_G.ws.spaces.iterm         -- snapshot(), snapshotAsync(cb), newWindow, newTab, focusTab
_G.ws.spaces.labels        -- getCurrentLabel, set, clear, prune, rebind
_G.ws.spaces.switcher      -- getSpacesForCurrentScreen, gotoSpace, show
_G.ws.spaces.banner        -- show
_G.ws.spaces.manager       -- createNewSpace, confirmCloseCurrentSpace
_G.ws.spaces.profiles      -- saveCurrentSpace, restoreProfile, listProfiles
_G.ws.spaces.launcher      -- newAgentSpace, newAgentTabHere, openChrome, openITerm
_G.ws.spaces.menubar       -- widget control, update()
```

Useful queries:

```lua
-- What's the agent state map look like?
_G.ws.spaces.agents.summary()
-- → { run = N, wait = N, done = N, err = N, idle = N }

-- All agents on the current space
local sid = _G.ws.spaces.agents.summary  -- placeholder; use snippet below
hs.fnutils.imap(_G.ws.spaces.agents.forSpace(sid), function(r)
  return r.title .. " [" .. r.state .. "]"
end)

-- Force a snapshot synchronously (for one-off inspection)
local s = _G.ws.spaces.iterm.snapshot()
print(#s.windows .. " windows")

-- Reload menubar title
_G.ws.spaces.menubar.update()
```

## File data

User data lives in `~/.hammerspoon/` and is **not** synced from the repo:

- `workspace-notes.json` — labels, space → label mapping, agent cwd recents (LRU, max 10)
- `space-profiles/<name>.json` — saved profiles (one per file)

Schema for `workspace-notes.json`:

```json
{
  "labels":   { "Spinnaker": { "lastUsed": 1746728000 }, ... },
  "spaces":   { "12345": "Spinnaker", ... },
  "agentCwds": ["/Users/.../Work/...", "..."]
}
```

## Common operations

### Add an existing agent space to the menubar

Just label the space (`⌘⌃⇧L`). Agent state appears automatically once the agent starts emitting `[spaces:run] ...` titles.

### Disable agent polling temporarily

```lua
_G.ws.spaces.agents.stop()
-- ... do stuff ...
_G.ws.spaces.agents.start()
```

### Tune polling cadence

Edit `core/config.lua` `poll.foregroundSec` / `poll.backgroundSec`, then `./bootstrap.sh -f && hs -c "hs.reload()"`.

### Diagnose slow menu

Time the build path:

```lua
local t0 = hs.timer.absoluteTime()
_G.ws.spaces.menubar.update()
print(string.format("%.1f ms", (hs.timer.absoluteTime() - t0) / 1e6))
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Menubar widget invisible | SF Symbol failed to load AND no label — fallback glyph should appear; if not, check the title-building code paths |
| Menu opens slowly | `iterm.snapshot()` (sync) called on the build path? It shouldn't be — see `systemPatterns.md` async pattern |
| Agent state doesn't update | Polling stopped? Run `_G.ws.spaces.agents.summary()` and confirm non-zero counts; check `agents.start()` was called |
| Wrong space label briefly shown after switch | Space-watcher fires before focus settles; 200ms `timer.doAfter` delay is in place |
| Tab title overwritten by shell | iTerm's shell integration sets the title on every prompt; emit your OSC escape from inside the shell instead of via `set name` |

## Changes from the old `modules/` layout (deleted in v1)

- `modules/` folder gone; product lives in `spaces/{core,ui,actions}/`.
- Five duplicate `findAndMoveNewWindow*` loops collapsed into `core/iterm.lua` and `core/chrome.lua`.
- Console namespace moved from flat `ws.labels` etc. to `ws.spaces.<module>`.
- `ws.menubar.update()` → `_G.ws.spaces.menubar.update()`.
- All `print()` debug chatter routed through `core/log.lua` (default level info).
