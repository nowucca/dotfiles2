# Hammerspoon Features Documentation

## Overview
Hammerspoon provides macOS Space labeling, switching, and workspace profile management via a menubar widget and keyboard shortcuts.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⌃L` | Set label for current space |
| `⌘⌃⇧L` | Show current label as banner |
| `⌘⌃Space` | Open space switcher |
| `⌘⌃S` | Save current space as profile |
| `⌘⌃R` | Restore profile to current space |

## Menubar Widget

### Location
- Shows in macOS menubar as 🏷️ icon
- Displays current space's label (if set)
- Cmd+drag to reposition

### Menu Items
1. **Current: [label]** - Shows current space label
2. **Set Label...** - Open label dialog
3. **Switch Space...** - Open space switcher
4. **Clear Label** - Remove label from current space (if labeled)
5. **Apply Label** - List of existing labels to apply
6. **Delete a Label...** - Remove label from system
7. **Prune Labels** - Remove old unused labels (7/30/90 days)
8. **Space Profiles:**
   - Save Space Profile...
   - Restore Profile...
   - Delete Profile...
9. **Show Banner** - Display label as overlay
10. **Debug Info** - Show screen/space information

## Features in Detail

### Space Labeling
Assign human-readable names to macOS Spaces (virtual desktops).

**Usage:**
1. Press `⌘⌃L` or click "Set Label..." in menu
2. Enter a label (e.g., "Development", "Email", "Slack")
3. Label appears in menubar and space switcher

**Notes:**
- Labels persist across Hammerspoon reloads
- Space IDs change on macOS restart (use "Apply Label" to re-assign)
- Labels track "last used" timestamp for pruning

### Space Switching
Navigate between spaces using a searchable chooser UI.

**Usage:**
1. Press `⌘⌃Space`
2. Type to filter by label
3. Arrow keys to select, Enter to switch
4. Escape to cancel

**Display:**
- `→ Label` indicates current space
- Unlabeled spaces show as "Space N"

### Space Profiles
Save and restore the set of apps on a space.

**Save Profile:**
1. Open apps you want on this space
2. Press `⌘⌃S`
3. Enter profile name (defaults to current label)
4. Profile saves: label + list of apps

**Restore Profile:**
1. Go to the space you want to configure
2. Press `⌘⌃R`
3. Select a profile from the list
4. Apps launch and move to current space

**What Gets Saved:**
- Space label
- List of apps with windows on space
- App bundle IDs

**What Gets Restored:**
- Label applied to current space
- Apps launched (staggered to avoid overload)
- New windows moved to current space

**Special Handling:**
- **iTerm**: Creates new window via AppleScript, moves to current space
  (This handles the case where iTerm is already open on another space)

### Label Management

**Prune Labels:**
Remove labels not used for N days
- 7 days - aggressive cleanup
- 30 days - moderate cleanup
- 90 days - conservative cleanup

**Delete Label:**
Removes specific label from the system
- Also clears the label from any spaces using it

## Console Access (Debugging)

Access modules via the `ws` global in Hammerspoon console:

```lua
-- Get current label
ws.labels.getCurrentLabel()

-- List apps on current space
for _, app in ipairs(ws.profiles.getAppsOnCurrentSpace()) do
  print(app.name)
end

-- List saved profiles
for _, p in ipairs(ws.profiles.listProfiles()) do
  print(p.name, #p.apps .. " apps")
end

-- Manually save profile
ws.profiles.saveCurrentSpace("MyProfile")

-- Reload menubar
ws.menubar.update()
```

## File Locations

### Code (version controlled)
```
~/Work/dotfiles/.hammerspoon/
├── init.lua
└── modules/
    ├── data.lua
    ├── space-labels.lua
    ├── space-switcher.lua
    ├── menubar.lua
    └── profiles.lua
```

### Data (not version controlled)
```
~/.hammerspoon/
├── workspace-notes.json    # Labels and space assignments
└── space-profiles/         # Saved profiles
    ├── Development.json
    └── Email.json
```

## Development Workflow

### Quick Commands
```bash
hsed    # cd to hammerspoon dotfiles
hsr     # sync and reload
hsr!    # reload only (no sync)
hss     # sync only (no reload)
hsc     # run hammerspoon command
```

### Making Changes
1. `hsed` - go to dotfiles hammerspoon dir
2. Edit files in your editor
3. `hsr` - sync to ~/.hammerspoon and reload
4. Test changes
5. Commit to git

## Troubleshooting

### Labels not showing after restart
Space IDs change when macOS restarts. Use "Apply Label" from the menu to re-assign labels to spaces.

### Module not found error
Check that `hsr` was run to sync files. Check Hammerspoon console for specific error.

### Menubar not updating
Try `ws.menubar.update()` in console, or run `hsr!` to reload.

### Profile restore not working
- Check console for errors
- Ensure apps are installed
- Some apps may not create windows immediately

### iTerm appearing on wrong space
The profile system creates new iTerm windows via AppleScript and moves them. If this fails, check:
- iTerm accessibility permissions
- Console for AppleScript errors
