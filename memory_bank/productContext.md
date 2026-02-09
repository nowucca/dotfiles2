# Product Context - Dotfiles

## Problem Statement
Setting up a new development machine is time-consuming and error-prone. Personal preferences, shortcuts, and configurations are lost or inconsistent across machines.

## Solution Approach
A version-controlled repository of configuration files ("dotfiles") that can be:
1. Cloned to any new machine
2. Symlinked to home directory
3. Kept in sync across machines via git

## User Needs

### Primary Workflows
1. **New Machine Setup** - Clone repo, run bootstrap, get productive quickly
2. **Configuration Updates** - Edit in dotfiles, sync across machines
3. **Workspace Management** - Use Hammerspoon to label and organize macOS Spaces

### Key User Stories
- As a developer, I want consistent shell aliases across all my machines
- As a developer, I want my Git config (name, email, preferences) everywhere
- As a macOS user, I want to label my Spaces so I can remember what each is for
- As a developer moving between projects, I want to quickly restore a workspace setup

## User Experience Goals

### Shell Experience
- Fast shell startup
- Intuitive aliases (short, memorable)
- Powerful navigation (z, directory shortcuts)
- Git integration in prompt

### Hammerspoon Experience
- Menubar widget shows current Space label
- Keyboard shortcuts for quick labeling
- Space switcher with searchable labels
- Save/restore workspace profiles

## Success Metrics
- Time to productive on new machine: < 30 min
- Shell startup time: < 500ms
- Space labeling is discoverable and intuitive
