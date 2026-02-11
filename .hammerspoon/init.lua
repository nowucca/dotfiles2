-- ============================================
-- HAMMERSPOON CONFIGURATION
-- Modular architecture - each feature is self-contained
-- ============================================

require("hs.ipc")

-- Add modules directory to package path
package.path = hs.configdir .. "/modules/?.lua;" .. package.path

-- ============================================
-- LOAD MODULES
-- ============================================

local spaceLabels = require("space-labels")
local spaceSwitcher = require("space-switcher")
local profiles = require("profiles")
local menubar = require("menubar")
local appLauncher = require("app-launcher")
local spaceManager = require("space-manager")

-- ============================================
-- INITIALIZE
-- ============================================

print("Hammerspoon loading...")

-- Initialize space manager with dependencies
spaceManager.init({
  spaceLabels = spaceLabels,
  appLauncher = appLauncher
})

-- Initialize menubar with dependencies
menubar.init({
  spaceLabels = spaceLabels,
  spaceSwitcher = spaceSwitcher,
  profiles = profiles,
  appLauncher = appLauncher,
  spaceManager = spaceManager
})

-- Connect app launcher callback to refresh menubar after window launch
appLauncher.onWindowLaunched = function()
  menubar.update()
end

-- ============================================
-- KEYBOARD SHORTCUTS
-- ============================================

-- Cmd+Ctrl+L - Set space label
hs.hotkey.bind({"cmd", "ctrl"}, "L", function()
  spaceLabels.promptForLabel()
end)

-- Cmd+Ctrl+Shift+L - Show current label as banner
hs.hotkey.bind({"cmd", "ctrl", "shift"}, "L", function()
  spaceLabels.show()
end)

-- Cmd+Ctrl+Space - Show space switcher
hs.hotkey.bind({"cmd", "ctrl"}, "space", function()
  spaceSwitcher.show()
end)

-- Cmd+Ctrl+S - Save current space as profile
hs.hotkey.bind({"cmd", "ctrl"}, "S", function()
  profiles.promptSaveCurrentSpace()
end)

-- Cmd+Ctrl+R - Restore profile to current space
hs.hotkey.bind({"cmd", "ctrl"}, "R", function()
  profiles.showRestoreChooser()
end)

-- Cmd+Ctrl+N - Open new app on current space (shows chooser)
hs.hotkey.bind({"cmd", "ctrl"}, "N", function()
  appLauncher.showLauncher()
end)

-- Cmd+Ctrl+Shift+C - Open Chrome on current space
hs.hotkey.bind({"cmd", "ctrl", "shift"}, "C", function()
  appLauncher.openChrome()
end)

-- Cmd+Ctrl+T - Open iTerm on current space
hs.hotkey.bind({"cmd", "ctrl"}, "T", function()
  appLauncher.openITerm()
end)

-- Create new space is available via menubar (no keyboard shortcut to avoid conflicts)
-- spaceManager.createNewSpace()

-- Cmd+Ctrl+W - Close current space (with confirmation)
hs.hotkey.bind({"cmd", "ctrl"}, "W", function()
  spaceManager.confirmCloseCurrentSpace()
end)

-- ============================================
-- GLOBAL ACCESS (for console debugging)
-- ============================================

ws = {
  labels = spaceLabels,
  switcher = spaceSwitcher,
  profiles = profiles,
  menubar = menubar,
  launcher = appLauncher,
  manager = spaceManager
}

-- ============================================
-- READY
-- ============================================

hs.alert.show("Hammerspoon loaded! 🏷️")
print("Hammerspoon loaded successfully!")
print("Shortcuts:")
print("  Cmd+Ctrl+L         - Set label")
print("  Cmd+Ctrl+Shift+L   - Show label banner")
print("  Cmd+Ctrl+Space     - Switch space")
print("  Cmd+Ctrl+S         - Save space profile")
print("  Cmd+Ctrl+R         - Restore profile")
print("  Cmd+Ctrl+N         - Open app on current space (chooser)")
print("  Cmd+Ctrl+Shift+C   - Open Chrome on current space")
print("  Cmd+Ctrl+T         - Open iTerm on current space")
print("  (Menubar)          - Create new space (iTerm + Chrome)")
print("  Cmd+Ctrl+W         - Close current space")
print("Modules: ws.labels, ws.switcher, ws.profiles, ws.menubar, ws.launcher, ws.manager")
