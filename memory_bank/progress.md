# Progress — Dotfiles

## State

| Component | Status |
|-----------|--------|
| Modular zsh config | ✅ Stable since 2026-02-09 |
| tmux config | ✅ Stable since 2026-02-09 |
| Hammerspoon host (init.lua, products.lua) | ✅ Cut over 2026-05-08 |
| Spaces product | ✅ Extracted to `~/spaces/hs-spaces/`. v1 shipped, v1.5 in progress (in that repo) |
| ctx-lenses shell integration | ✅ |

For Spaces product progress (v1 task ledger, post-launch fixes, v1.5 outstanding work, v2 deferred), see `~/spaces/hs-spaces/hs-spaces/main/memory_bank/progress.md`.

## Recent dotfiles work

### 2026-05-10: Picked up accumulated machine + tooling config

Cleared backlog of unstaged changes (commit `6350bf8`):

- `.gitconfig` — Metatron autoconfig block (managed by `metatron` CLI), Netflix stash + GHE SSL client-cert config, `push.autoSetupRemote = true`, user identity.
- `.zsh/aliases/claude.zsh` — `cc` and `cr` aliases (`claude --dangerously-skip-permissions` and its `--resume` variant).
- `.zsh/tools/ctx.zsh` — one-liner sourcing ctx-lenses shell integration. Auto-picked by the `.zsh/tools/*.zsh` loop.
- `.zshrc` — belt-and-suspenders eval of ctx-lenses setup.
- `CLAUDE.md` — repo-level reminder pointing at `./bootstrap.sh -f` as the deploy command.

Pushed both remotes: `origin` (github.com/nowucca/dotfiles2) and `netflix` (git.netflix.net/corp/satkinson-dotfiles).

### 2026-05-08: Spaces extracted; dotfiles becomes host-only

- Moved Lua product from `.hammerspoon/spaces/` (~25 files) to its own repo at `~/spaces/hs-spaces/hs-spaces/main/`.
- Replaced with absolute symlinks; `bootstrap.sh` preserves them via `rsync -al`.
- Trimmed `memory_bank/` to dotfiles-only with pointers to the new repo for product detail.
- Host `init.lua` was already in place from the v1 cutover (commit `35e43cf`).

### 2026-05-08: Spaces v1 → main-zsh

Merged 26 commits from `feat/spaces-v1` into `main-zsh` (fast-forward). Branch deleted.

### 2026-02-09: Modular zsh + tmux finalized

- `.zsh/{core,aliases,functions,tools,prompt.zsh,netflix.zsh}` structure
- NVM/SDKMAN lazy-loaded
- tmux with vim navigation, splits, mouse, Solarized

## Outstanding

### Cleanup

- [ ] Eventually delete the design history at `docs/superpowers/{specs,plans}/2026-05-08-spaces-*` if the canonical copy in the hs-spaces repo is sufficient — leaving for now as a historical record of when/where the design happened.

### Future enhancements

- [ ] tmux plugin manager (TPM) for resurrect/continuum — unconfirmed if worth the dependency.
- [ ] Async git prompt for even faster rendering on huge repos.
- [ ] `pushall` alias for one-command multi-remote push (currently `git push origin main-zsh && git push netflix main-zsh`).

## Testing checklist for any zsh change

1. `./bootstrap.sh -f`
2. `time zsh -i -c exit` — should be < 100ms
3. Spot-check aliases: `ll`, `..`, `g status`
4. Lazy load: `node --version` (triggers NVM)

## Testing checklist for any Hammerspoon host change

1. `./bootstrap.sh -f`
2. `hs -c "hs.reload()"`
3. `hs -c "_G.ws.spaces.config.brand.version"` — should print `1.0.0`

For Spaces product testing, see that repo's `memory_bank/progress.md`.

## Timeline

| Date | Milestone |
|------|-----------|
| 2026-02-06 | Hammerspoon modular architecture (original `modules/`) |
| 2026-02-09 | Shell + tmux modular config |
| 2026-05-08 | Spaces v1 designed, planned, implemented (18 tasks), cutover |
| 2026-05-08 | Spaces v1 polish: visibility, async polling, cached menu |
| 2026-05-08 | Merged to `main-zsh`; extracted to `~/spaces/hs-spaces/` |
