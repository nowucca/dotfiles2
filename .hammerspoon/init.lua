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

-- ============================================
-- INITIALIZE
-- ============================================

print("Hammerspoon loading...")

-- Initialize menubar with dependencies
menubar.init({
  spaceLabels = spaceLabels,
  spaceSwitcher = spaceSwitcher,
  profiles = profiles
})

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

-- ============================================
-- GLOBAL ACCESS (for console debugging)
-- ============================================

ws = {
  labels = spaceLabels,
  switcher = spaceSwitcher,
  profiles = profiles,
  menubar = menubar
}

-- ============================================
-- READY
-- ============================================

hs.alert.show("Hammerspoon loaded! 🏷️")
print("Hammerspoon loaded successfully!")
print("Shortcuts:")
print("  Cmd+Ctrl+L       - Set label")
print("  Cmd+Ctrl+Shift+L - Show label banner")
print("  Cmd+Ctrl+Space   - Switch space")
print("  Cmd+Ctrl+S       - Save space profile")
print("  Cmd+Ctrl+R       - Restore profile")
print("Modules: ws.labels, ws.switcher, ws.profiles, ws.menubar")
