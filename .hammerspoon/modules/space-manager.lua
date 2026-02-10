-- ============================================
-- SPACE MANAGER MODULE
-- Create and close spaces (Mission Control desktops)
-- ============================================

local M = {}

local spaces = require("hs.spaces")
local screen = require("hs.screen")
local window = require("hs.window")
local timer = require("hs.timer")
local alert = require("hs.alert")
local dialog = require("hs.dialog")

-- Dependencies (set during init)
local spaceLabels = nil
local appLauncher = nil

-- ============================================
-- HELPERS
-- ============================================

-- Get current space info including screen reference
local function getCurrentSpaceInfo()
  local win = window.focusedWindow()
  local scr = win and win:screen() or screen.mainScreen()
  if not scr then return nil, nil end
  local uuid = scr:getUUID()
  local spaceId = spaces.activeSpaces()[uuid]
  return spaceId, scr
end

-- Get all windows on a specific space
local function getWindowsOnSpace(spaceId)
  local windows = {}
  local winIds = spaces.windowsForSpace(spaceId) or {}
  for _, winId in ipairs(winIds) do
    local win = window.get(winId)
    if win and win:isStandard() then
      table.insert(windows, win)
    end
  end
  return windows
end

-- ============================================
-- CLOSE SPACE
-- ============================================

-- Close all windows on the current space, then remove the space
function M.closeCurrentSpace()
  local spaceId, scr = getCurrentSpaceInfo()
  if not spaceId or not scr then
    alert.show("Cannot determine current space")
    return
  end
  
  -- Get all spaces on this screen
  local screenUUID = scr:getUUID()
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  
  -- Don't close if it's the only space on this screen
  if #screenSpaces <= 1 then
    alert.show("Cannot close: only one space on this screen")
    return
  end
  
  -- Get label for display
  local label = spaceLabels and spaceLabels.getCurrentLabel() or ("Space " .. tostring(spaceId))
  
  print("space-manager: Closing space " .. tostring(spaceId) .. " (" .. label .. ")")
  
  -- Get all windows on this space
  local windows = getWindowsOnSpace(spaceId)
  local windowCount = #windows
  
  print("space-manager: Found " .. windowCount .. " windows to close")
  
  -- Close all windows
  for _, win in ipairs(windows) do
    local app = win:application()
    local appName = app and app:name() or "Unknown"
    print("space-manager: Closing " .. appName .. " window " .. tostring(win:id()))
    win:close()
  end
  
  -- Wait for windows to close, then remove the space
  timer.doAfter(0.5, function()
    -- Check if windows are closed
    local remainingWindows = getWindowsOnSpace(spaceId)
    if #remainingWindows > 0 then
      print("space-manager: " .. #remainingWindows .. " windows still open, waiting longer...")
      timer.doAfter(1.0, function()
        M.removeSpaceIfEmpty(spaceId, scr, label, windowCount)
      end)
    else
      M.removeSpaceIfEmpty(spaceId, scr, label, windowCount)
    end
  end)
end

-- Remove a space if it's empty (or nearly empty)
function M.removeSpaceIfEmpty(spaceId, scr, label, originalWindowCount)
  print("space-manager: Attempting to remove space " .. tostring(spaceId))
  
  -- Remove the space
  local result = spaces.removeSpace(spaceId)
  
  if result then
    print("space-manager: Space removed successfully")
    alert.show("Closed: " .. label .. " (" .. originalWindowCount .. " windows)")
  else
    print("space-manager: Failed to remove space")
    alert.show("Closed windows but couldn't remove space")
  end
end

-- Confirm before closing space
function M.confirmCloseCurrentSpace()
  local spaceId, scr = getCurrentSpaceInfo()
  if not spaceId then
    alert.show("Cannot determine current space")
    return
  end
  
  local label = spaceLabels and spaceLabels.getCurrentLabel() or ("Space " .. tostring(spaceId))
  local windows = getWindowsOnSpace(spaceId)
  
  local button = dialog.blockAlert(
    "Close Space: " .. label .. "?",
    "This will close " .. #windows .. " window(s) and remove this desktop.",
    "Close Space",
    "Cancel"
  )
  
  if button == "Close Space" then
    M.closeCurrentSpace()
  end
end

-- ============================================
-- CREATE SPACE
-- ============================================

-- Create a new space on the current screen, switch to it, open default apps
function M.createNewSpace()
  local _, scr = getCurrentSpaceInfo()
  if not scr then
    scr = screen.mainScreen()
  end
  
  if not scr then
    alert.show("No screen found")
    return
  end
  
  print("space-manager: Creating new space on " .. scr:name())
  alert.show("Creating new space...")
  
  -- Create a new space on the current screen
  local newSpaceId = spaces.addSpaceToScreen(scr, true)  -- true = user space (vs fullscreen)
  
  if not newSpaceId then
    print("space-manager: Failed to create new space")
    alert.show("Failed to create new space")
    return
  end
  
  print("space-manager: Created space " .. tostring(newSpaceId))
  
  -- Switch to the new space
  timer.doAfter(0.3, function()
    print("space-manager: Switching to space " .. tostring(newSpaceId))
    spaces.gotoSpace(newSpaceId)
    
    -- Wait for space switch to complete
    timer.doAfter(0.5, function()
      -- Launch default apps (iTerm and Chrome)
      M.setupNewSpace(newSpaceId, scr)
    end)
  end)
end

-- Set up a new space with default apps
function M.setupNewSpace(spaceId, scr)
  print("space-manager: Setting up new space with default apps")
  
  -- Launch iTerm first
  if appLauncher then
    appLauncher.openITerm()
    
    -- Launch Chrome after iTerm
    timer.doAfter(2.5, function()
      appLauncher.openChrome()
      
      -- Prompt for label after apps are launched
      timer.doAfter(2.5, function()
        M.promptForNewSpaceLabel()
      end)
    end)
  else
    -- Fallback if appLauncher not available
    print("space-manager: appLauncher not available, prompting for label only")
    M.promptForNewSpaceLabel()
  end
end

-- Prompt for a label for the new space
function M.promptForNewSpaceLabel()
  if spaceLabels then
    spaceLabels.promptForLabel()
  else
    alert.show("New space ready (label module not available)")
  end
end

-- ============================================
-- INITIALIZATION
-- ============================================

function M.init(deps)
  spaceLabels = deps.spaceLabels
  appLauncher = deps.appLauncher
end

return M
