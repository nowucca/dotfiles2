# Product Context

## Why this repo

Two intertwined goals:

1. **Portable shell + dev environment.** Consistent zsh, tmux, git config across machines. New machine gets productive fast via `bootstrap.sh`.
2. **Native macOS desktop for agentic work.** Long-running AI agents (Claude Code, others) deserve a first-class operator surface. Not an IDE — the menubar, spaces, and choosers that macOS already provides, with the right glue.

## The Spaces product

### Problem

Running multiple AI agents simultaneously means juggling iTerm tabs across many macOS Spaces. There's no native way to:

- See which agents are running where, and what state they're in.
- Jump from a notification to the specific tab that needs attention.
- Spin up a new agent in a fresh, labelled space without manual setup.
- Keep the agent surface and the rest of macOS distinct.

Without dedicated tooling, the operator either keeps an IDE focused (which is its own context switch) or loses track of agents.

### Solution

A branded Hammerspoon product that:

- Surfaces agent state in the menubar using a tab-title convention agents emit (`[spaces:STATE] task`). State map updated by background polling — UI never blocks on AppleScript.
- Provides two fixed launchers:
  - `⌘⌃A` — new labelled space + iTerm with `claude` running in a chosen cwd.
  - `⌘⌃⇧A` — new tab on current space + `claude` in a chosen cwd.
- Preserves the existing space-management workflow (label, switch, save/restore profiles, create/close spaces) the user already has muscle memory for.
- Ships with a tiny zsh shim (`spaces_state run/wait/done/err`) so agent runners can announce state in one line.

### User stories

- *I'm running three Claude agents on three spaces. I glance at the menubar and see one is awaiting input.* (Click-to-focus targeted at v2.)
- *I want to start a new agent on a fresh space.* `⌘⌃A`, type a label, pick a cwd from recents, hit return.
- *I'm reviewing a PR in one tab and want a new agent in a new tab on this same space.* `⌘⌃⇧A`.
- *I have a complex space layout I want back later.* Save profile, restore later.

### What ships in v1

Branding polish (name, glyph, voice, About dialog, version, quiet logging), agent run tracking via tab-title parsing, the two launchers, the cleaned-up product folder layout. v1.5 will extract the product to its own repo with a manuals v2 site and an installable Claude skill. v2 brings native notifications and templated launchers.

### What doesn't ship in v1

Agent notifications (deferred to v2), templated launchers (v2), iTerm side-panel integration, multi-machine sync.

## User experience goals

- **The menubar is the surface.** Always visible. Click to expand to current space → windows → tabs. Click a tab to focus it.
- **Voice is workmanlike.** "Spinnaker ready", "Closed Spinnaker · 4 windows", "No active space". No emoji, no exclamations.
- **Native everywhere.** macOS Spaces, hs.alert, hs.dialog, hs.chooser. No web views, no Electron.
- **Quiet by default.** Hammerspoon console at info level shows the start-up line and nothing else under normal use.

## Success metrics

- Operator can run 3+ agents without losing track of any.
- New agent spun up in under 5 seconds.
- Menubar opens instantly (< 50ms) regardless of agent load.
- Polling cost invisible — main thread never blocks on AppleScript.
