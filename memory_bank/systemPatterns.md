# System Patterns - Dotfiles

## Shell Configuration Architecture

### Directory Structure
```
~/Work/dotfiles/
├── .zshrc              # Main loader (modular)
├── .zshenv             # Environment variables (SINGLE SOURCE OF TRUTH)
├── .tmux.conf          # Tmux configuration
├── .zsh/               # Modular configuration directory
│   ├── README.md       # Documentation
│   ├── core/           # Core shell settings
│   │   ├── options.zsh     # setopt, bindkey
│   │   ├── path.zsh        # PATH (single source of truth)
│   │   ├── history.zsh     # History configuration
│   │   └── completions.zsh # Completion system with caching
│   ├── aliases/        # Organized by topic
│   │   ├── navigation.zsh  # .., cd shortcuts
│   │   ├── general.zsh     # Basic shell aliases
│   │   ├── macos.zsh       # macOS-specific (colors, Finder)
│   │   ├── dev.zsh         # Development (Java, Maven, Gradle)
│   │   ├── git.zsh         # Git aliases
│   │   ├── hammerspoon.zsh # Hammerspoon shortcuts
│   │   └── tmux.zsh        # Tmux session management
│   ├── functions/      # Shell functions
│   │   ├── utils.zsh       # mkd, fs, targz, etc.
│   │   └── network.zsh     # digga, getcertnames, server
│   ├── tools/          # External tool integration
│   │   ├── z.zsh           # Directory jumping
│   │   ├── nvm.zsh         # Node (lazy loaded)
│   │   └── sdkman.zsh      # SDKMAN (lazy loaded)
│   ├── prompt.zsh      # Git-aware prompt with fast mode
│   └── netflix.zsh     # Work-specific config
├── .hammerspoon/       # macOS automation
│   ├── init.lua
│   └── modules/
└── bootstrap.sh        # Machine setup script
```

### Loading Order
1. `.zshenv` - Environment variables (all shell types)
2. `.zshrc` - Interactive shells only:
   - Platform detection functions (`is_mac`, `is_linux`, `is_coder_workspace`)
   - Core modules (path, history, options, completions)
   - Tools (z, nvm stub, sdkman stub)
   - Prompt
   - Aliases
   - Functions
   - Netflix config
   - Local `~/.extra` overrides

## Performance Patterns

### Lazy Loading
Slow tools are lazy-loaded - only initialized on first use:

```zsh
# NVM lazy loading pattern (~1000ms savings)
nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm "$@"
}
```

### Completion Caching
Completions compiled and cached for 24 hours:
```zsh
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
    { zcompile "${ZDOTDIR:-$HOME}/.zcompdump" } &!
else
    compinit -C
fi
```

### Fast Git Prompt
Large repos (Netflix, >100MB .git) skip dirty checks:
```zsh
# Show ⚡ instead of +!?$ status for fast mode
if (( use_fast_mode )); then
    s+='⚡'
fi
```

### Hardcoded Paths
Avoid slow command substitution:
```zsh
# Instead of: eval "$(brew shellenv)"
export HOMEBREW_PREFIX="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
```

## Tmux Configuration

### Key Bindings
- **Prefix**: `Ctrl+A` (screen-style)
- **Splits**: `|` horizontal, `-` vertical (stay in current path)
- **Pane navigation**: `hjkl` (vim-style)
- **Window switching**: `Alt+1-9` (no prefix needed)
- **Reload**: `Ctrl+A r`
- **Sync panes**: `Ctrl+A S` (type in all panes)

### Aliases (`.zsh/aliases/tmux.zsh`)
```zsh
tmx [name]      # Attach or create session
tmdev [name]    # Create 3-window dev layout
tmkill          # Interactive session killer
tmls            # List sessions
```

## Hammerspoon Architecture

### Module Structure
```
~/.hammerspoon/
├── init.lua             # Entry point (~80 lines)
├── modules/
│   ├── data.lua         # JSON persistence
│   ├── space-labels.lua # Space naming
│   ├── space-switcher.lua # Keyboard navigation
│   ├── menubar.lua      # UI in menubar
│   └── profiles.lua     # Workspace profiles
├── workspace-notes.json # User data (not synced)
└── space-profiles/      # Saved profiles (not synced)
```

### Module Communication
- Modules return tables with public functions
- Callbacks connect modules: `onLabelChanged`, `onSpaceChanged`
- Data module handles all JSON I/O

## Maintenance Patterns

### Adding New Aliases
1. Choose appropriate file in `.zsh/aliases/`
2. Or create new topic file: `.zsh/aliases/mytopic.zsh`
3. Run `./bootstrap.sh -f` to sync

### Adding New Functions
Add to `.zsh/functions/utils.zsh` or create topic-specific file

### Adding Lazy-Loaded Tool
Create `.zsh/tools/mytool.zsh`:
```zsh
mytool() {
    unset -f mytool
    source /path/to/init.sh
    mytool "$@"
}
```

### Platform-Specific Code
```zsh
is_mac || return 0  # Skip entire file on non-macOS
is_mac && command   # Inline conditional
```

## Applying Changes

```bash
cd ~/Work/dotfiles
./bootstrap.sh -f
```

### Benchmarking
```bash
time zsh -i -c exit  # Single run
for i in {1..5}; do time zsh -i -c exit; done  # Average
```
Target: < 100ms on modern hardware
