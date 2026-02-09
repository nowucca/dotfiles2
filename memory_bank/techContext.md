# Technical Context - Dotfiles

## Technologies & Frameworks

### Shell
- **Zsh** - Primary shell with modular configuration
- **No Oh My Zsh** - Custom config for speed
- **z** - Directory jumping (in `init/z/`)

### Terminal Multiplexer
- **tmux** - Session management with vim keybindings
  - Prefix: `Ctrl+A`
  - Vim-style navigation
  - Solarized theme

### macOS Automation
- **Hammerspoon** - Lua-based automation
  - Modules: hs.spaces, hs.menubar, hs.chooser, hs.osascript
  - API Docs: https://www.hammerspoon.org/docs/

### Package Management
- **Homebrew** - macOS package manager
- **npm** - Node.js packages (some global tools)

## Development Environment

### File Locations
```
~/Work/dotfiles/          # Source of truth (git repo)
├── .zsh/                 # Modular shell config
│   ├── core/             # options, path, history, completions
│   ├── aliases/          # by topic (nav, macos, dev, git, tmux, etc.)
│   ├── functions/        # utils, network
│   ├── tools/            # z, nvm, sdkman (lazy loaded)
│   ├── prompt.zsh
│   └── netflix.zsh
├── .zshrc                # Main loader
├── .zshenv               # Environment variables
├── .tmux.conf            # Tmux configuration
├── .hammerspoon/         # Hammerspoon config (development)
├── memory_bank/          # Documentation
└── bin/                  # Scripts

~/.hammerspoon/           # Runtime location (synced from dotfiles)
├── init.lua
├── modules/
├── workspace-notes.json  # User data (NOT synced)
└── space-profiles/       # User data (NOT synced)
```

### Sync Workflow
```bash
# Sync all dotfiles to home directory
cd ~/Work/dotfiles
./bootstrap.sh -f

# For Hammerspoon specifically
hsr  # sync and reload
```

### Key Scripts
- `bootstrap.sh` - Sync dotfiles to home directory
- `bin/sync-hammerspoon.sh` - Copies HS config to ~/.hammerspoon

## Code Patterns

### Zsh Module Pattern
```zsh
#!/usr/bin/env zsh
# .zsh/aliases/mytopic.zsh

# Skip on non-macOS if needed
is_mac || return 0

alias myalias='mycommand'

function myfunction() {
    # implementation
}
```

### Lazy Loading Pattern
```zsh
# .zsh/tools/mytool.zsh
mytool() {
    unset -f mytool
    source /path/to/init.sh
    mytool "$@"
}
```

### Hammerspoon Module Pattern
```lua
-- modules/example.lua
local M = {}

local dependency = require("modules.dependency")

function M.publicFunction()
  -- ...
end

return M
```

## Common Issues & Debugging

### Shell
- **Slow startup**: Check `time zsh -i -c exit`, should be < 100ms
- **Aliases not available**: Run `./bootstrap.sh -f` or open new terminal
- **PATH issues**: Check `.zsh/core/path.zsh` (single source of truth)

### Tmux
- **Prefix not working**: Ensure `.tmux.conf` is synced (`Ctrl+A`, not `Ctrl+B`)
- **Reload config**: `Ctrl+A r`
- **Copy not working**: Use `v` to select, `y` to copy (uses pbcopy)

### Hammerspoon
- **Module not found**: Check `package.path` in init.lua
- **Nil errors**: Check module dependencies are loaded first
- **Changes not taking effect**: Run `hsr` to sync and reload
- **Console**: Open Hammerspoon Console for error logs

## CLI Commands
```bash
# Shell
time zsh -i -c exit     # Benchmark startup
./bootstrap.sh -f       # Sync dotfiles

# Tmux
tmx [name]              # Attach or create session
tmdev [name] [dir]      # Create dev layout (3 windows)
tmkill                  # Interactive session killer

# Hammerspoon
hss                     # Sync config
hsr                     # Sync and reload
hsr!                    # Reload only
hsc "command"           # Run HS command

# Dotfiles
dotf                    # cd to dotfiles
dotb                    # Bootstrap
```

## Performance Targets
- Shell startup: < 100ms
- NVM lazy load saves: ~1000ms
- SDKMAN lazy load saves: ~400ms
- Git prompt fast mode: Skips dirty checks for repos > 100MB
