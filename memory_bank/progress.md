# Progress - Dotfiles

## Spaces v1 (shipped, on `feat/spaces-v1`)

Branded Hammerspoon-hosted desktop product for running long-running agents from native macOS. Replaced the unbranded `.hammerspoon/modules/` toolkit with a deliberate product layout.

### v1 task ledger (all complete)

| # | Task | Commit |
|---|------|--------|
| 1  | Test harness + spaces/ skeleton | `0495b81` |
| 2  | core/config.lua | `2339004` |
| 3  | core/log.lua | `2a0e122` |
| 4  | core/data.lua (with `agentCwds`) | `8c8f762` + `bec25a3` (lifted-label fix) |
| 5  | core/agents.lua title parser | `193eac4` |
| 6  | core/iterm.lua snapshot | `72099c3` + `5258540` (space-resolve fix) |
| 7  | core/iterm.lua window/tab create + focus | `d042676` |
| 8  | core/chrome.lua | `3dd457b` |
| 9  | core/agents.lua state map + polling | `98ff428` |
| 10 | actions/labels.lua + ui/banner.lua | `8fac0fe` |
| 11 | ui/switcher.lua | `5ea09c6` |
| 12 | actions/space-manager.lua | `b973e11` |
| 13 | actions/profiles.lua | `322c106` |
| 14 | actions/launcher.lua (agent launchers + cwd recents) | `3712136` |
| 15 | ui/about.lua | `eebf6a1` |
| 16 | ui/menubar.lua (nested Space → Window → Tab) | `38436b1` |
| 17 | spaces/init.lua + zsh shim | `faba323` |
| 18 | Cutover (host init + delete modules/) | `35e43cf` |

### Post-launch fixes

| Fix | Commit |
|-----|--------|
| Always-visible menubar widget (text glyph fallback when SF Symbol unavailable), 5s/30s polling, drop window-focus filter | `6f3f5f2` |
| Menu builds from cached agent state instead of live snapshot | `1094119` |
| iTerm snapshot async via `hs.task` so polling never blocks main thread | `d02e9e3` |

### Test suite

71 tests across `test_config`, `test_log`, `test_data`, `test_agents_parser`, `test_agents_state`. Runs in <100ms via `hs -c "dofile(hs.configdir .. '/spaces/test/run_all.lua')"`. Test harness force-clears cached `core/ui/actions` modules so edited code lands immediately.

UI/AppleScript surfaces (iterm, chrome, menubar, dialogs) are not unit-tested — verified manually via smoke tests in each task.

### Acceptance state

| Criterion | Status |
|-----------|--------|
| Hammerspoon reloads cleanly | ✅ |
| `~/.hammerspoon/modules/` removed | ✅ |
| `~/.hammerspoon/spaces/` exists | ✅ |
| `workspace-notes.json` + `space-profiles/` preserved | ✅ |
| Menubar widget visible | ✅ (fallback glyph; SF Symbol doesn't load) |
| Menu opens fast | ✅ (post-fix: cached state + async polling) |
| `_G.ws.spaces.config.brand.version == "1.0.0"` | ✅ |
| ⌘⌃A new agent space (live test) | not yet user-confirmed |
| ⌘⌃⇧A new agent tab here (live test) | not yet user-confirmed |
| Existing hotkeys (⌘⌃L, ⌘⌃Space, ⌘⌃B, ⌘⌃T, etc.) unchanged | not yet user-confirmed |
| Wrong-space-label bug | fix attempted (200ms watcher delay), unconfirmed |

## Earlier project state (still current)

### Modular zsh configuration (2026-02-09)

`.zsh/{core,aliases,functions,tools,prompt.zsh,netflix.zsh}`. NVM/SDKMAN lazy loaded. Solarized tmux. All commits already on `main-zsh`.

### Tmux

Vim navigation, `|`/`-` splits, mouse + pbcopy, Alt+1-9 window switch, Solarized.

## Future work

### v1.5 — Spaces own repo + manuals + skill (planned)

Extract `.hammerspoon/spaces/` to a new `spaces-hs` repo with:
- `manual/` — manuals v2 site (install, state convention, shim, troubleshooting)
- `.claude/skills/spaces.md` — installable Claude skill
- `install.sh` — clone + symlink + source

### v2 — Notifications, templates (deferred)

- Native banner on `run → done/wait/err`. Click → switch space + focus tab.
- Templated launchers from user-editable JSON.
- iTerm side-panel/status-bar integration.
- Sourcegraph/Slack/JIRA integration from menubar.

## Testing checklist for any zsh change

1. `./bootstrap.sh -f`
2. `time zsh -i -c exit` — should be < 100ms
3. Spot-check aliases: `ll`, `..`, `g status`
4. Lazy load: `node --version` (triggers NVM)

## Testing checklist for any Spaces change

1. `./bootstrap.sh -f`
2. `hs -c "hs.reload()"`
3. `hs -c "dofile(hs.configdir .. '/spaces/test/run_all.lua')"` — 71 tests, 0 failures
4. Click the menubar — should pop instantly
5. `_G.ws.spaces.agents.summary()` after a few seconds — should show idle count
