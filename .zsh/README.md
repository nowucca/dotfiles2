# Modular Zsh Configuration

This directory contains a modular zsh configuration optimized for:
- **Startup speed** - Lazy loading for slow tools (NVM ~1s, SDKMAN ~400ms)
- **Maintainability** - Organized by topic, easy to find and modify
- **Portability** - Platform detection (macOS, Linux, Coder workspaces)

## Directory Structure

```
.zsh/
├── core/               # Core shell settings
│   ├── options.zsh     # Zsh options (setopt, bindkey)
│   ├── path.zsh        # PATH configuration (single source of truth)
│   ├── history.zsh     # History settings
│   └── completions.zsh # Completion system with caching
│
├── aliases/            # Aliases organized by topic
│   ├── navigation.zsh  # cd shortcuts, directory navigation
│   ├── general.zsh     # Basic shell aliases
│   ├── macos.zsh       # macOS-specific (ls colors, Finder, etc.)
│   ├── dev.zsh         # Development (Java, Maven, Gradle)
│   ├── git.zsh         # Git aliases
│   ├── hammerspoon.zsh # Hammerspoon shortcuts
│   └── tmux.zsh        # Tmux session management
│
├── functions/          # Shell functions
│   ├── utils.zsh       # General utilities (mkd, fs, targz)
│   └── network.zsh     # Network functions (digga, getcertnames, server)
│
├── tools/              # External tool integration
│   ├── z.zsh           # Directory jumping
│   ├── nvm.zsh         # Node Version Manager (lazy loaded)
│   └── sdkman.zsh      # SDKMAN (lazy loaded)
│
├── prompt.zsh          # Prompt with git status (fast mode for large repos)
└── netflix.zsh         # Work-specific configuration
```

## Performance Features

### Lazy Loading
NVM and SDKMAN are lazy-loaded - they only initialize when you first use them:
- `nvm`, `node`, `npm`, `npx` → triggers NVM load
- `sdk` → triggers SDKMAN load

### Completion Caching
Completions are compiled and cached for 24 hours:
```zsh
# Only regenerates if cache is > 24 hours old
compinit -C  # Uses cached completions
```

### Fast Git Prompt
Large repositories (Netflix, Chromium, or >100MB .git) use fast mode:
- Shows branch name + ⚡ indicator
- Skips slow dirty/status checks

## Adding New Configuration

### New Alias Topic
Create `.zsh/aliases/mytopic.zsh`:
```zsh
#!/usr/bin/env zsh
# Description of aliases

alias myalias='mycommand'
```

### New Function
Add to existing file in `.zsh/functions/` or create new topic file.

### New Tool with Lazy Loading
Create `.zsh/tools/mytool.zsh`:
```zsh
#!/usr/bin/env zsh

# Define stub function that loads the real tool on first use
mytool() {
    unset -f mytool
    source /path/to/mytool/init.sh
    mytool "$@"
}
```

## Platform Checks

Use these functions to conditionally run code:
```zsh
is_mac && echo "Running on macOS"
is_linux && echo "Running on Linux"  
is_coder_workspace && echo "In Coder workspace"
```

## Benchmarking

Test shell startup time:
```bash
# Single run
time zsh -i -c exit

# Average of 5 runs
for i in {1..5}; do time zsh -i -c exit; done
```

Target: < 100ms on modern hardware.

## Applying Changes

Run `bootstrap.sh` to sync dotfiles to your home directory:
```bash
cd ~/Work/dotfiles
./bootstrap.sh -f
```

The old flat files (`.aliases`, `.functions`, `.exports`, `.path`) are replaced by this modular structure. The new `.zshrc` loads everything from `.zsh/`.

If you have customizations in `~/.extra`, they still work - loaded last for local overrides.
