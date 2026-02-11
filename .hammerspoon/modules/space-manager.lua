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

-- Get all space IDs for a screen as a set
local function getSpaceIdsForScreen(scr)
  local spaceIds = {}
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  for _, spaceId in ipairs(screenSpaces) do
    spaceIds[spaceId] = true
  end
  return spaceIds
end

-- Find the new space ID by comparing before/after space lists
local function findNewSpaceId(oldSpaceIds, scr)
  local newScreenSpaces = spaces.spacesForScreen(scr) or {}
  for _, spaceId in ipairs(newScreenSpaces) do
    if not oldSpaceIds[spaceId] then
      return spaceId
    end
  end
  return nil
end

-- Create a new space on the current screen, switch to it, open default apps
function M.createNewSpace()
  local currentSpaceId, scr = getCurrentSpaceInfo()
  if not scr then
    scr = screen.mainScreen()
  end
  
  if not scr then
    alert.show("No screen found")
    return
  end
  
  print("space-manager: Creating new space on " .. scr:name())
  
  -- FIRST: Prompt for the label before creating the space
  M.promptForLabelThenCreate(scr)
end

-- Prompt for label first, then create the space with that label
function M.promptForLabelThenCreate(scr)
  local button, labelName = dialog.textPrompt(
    "New Space",
    "Enter a label for the new space:",
    "",
    "Create",
    "Cancel"
  )
  
  if button ~= "Create" then
    return
  end
  
  -- Now create the space
  alert.show("Creating: " .. (labelName or "New Space") .. "...")
  
  -- Get existing spaces BEFORE creating new one
  local oldSpaceIds = getSpaceIdsForScreen(scr)
  print("space-manager: Existing spaces: " .. hs.json.encode(spaces.spacesForScreen(scr)))
  
  -- Create a new space on the current screen
  local result = spaces.addSpaceToScreen(scr, true)  -- true = user space (vs fullscreen)
  
  if not result then
    print("space-manager: Failed to create new space")
    alert.show("Failed to create new space")
    return
  end
  
  print("space-manager: addSpaceToScreen returned: " .. tostring(result))
  
  -- Wait a bit for the space to be created, then find it
  print("space-manager: Scheduling timer to find new space...")
  local timerObj = timer.doAfter(0.5, function()
    print("space-manager: Timer callback entered!")
    print("space-manager: Looking for new space...")
    local newScreenSpaces = spaces.spacesForScreen(scr) or {}
    print("space-manager: Spaces after creation: " .. hs.json.encode(newScreenSpaces))
    
    local newSpaceId = findNewSpaceId(oldSpaceIds, scr)
    
    if not newSpaceId then
      print("space-manager: Could not find new space ID - comparing lists failed")
      print("space-manager: Old IDs: " .. hs.json.encode(oldSpaceIds))
      alert.show("Created space but couldn't find it")
      return
    end
    
    print("space-manager: Found new space ID: " .. tostring(newSpaceId))
    
    -- Set the label immediately
    if labelName and labelName ~= "" and spaceLabels then
      local data = require("modules.data")
      local d = data.load()
      data.setLabelForSpace(d, tostring(newSpaceId), labelName)
      data.save(d)
      print("space-manager: Set label '" .. labelName .. "' for space " .. tostring(newSpaceId))
    end
    
    -- Switch to the new space
    print("space-manager: Switching to space " .. tostring(newSpaceId))
    local gotoResult = spaces.gotoSpace(newSpaceId)
    print("space-manager: gotoSpace returned: " .. tostring(gotoResult))
    
    -- Wait for space switch to complete, then launch apps with explicit target
    timer.doAfter(0.8, function()
      print("space-manager: Post-switch timer fired")
      
      -- Get current space - use screen directly instead of focused window
      local activeSpaces = spaces.activeSpaces()
      local screenUUID = scr:getUUID()
      local currentSpace = activeSpaces[screenUUID]
      print("space-manager: Now on space " .. tostring(currentSpace) .. " (target: " .. tostring(newSpaceId) .. ")")
      
      -- Launch default apps regardless of space check (we'll move them anyway)
      print("space-manager: Proceeding to setup apps...")
      M.setupNewSpaceWithTarget(newSpaceId, scr, labelName)
    end)
  end)
end

-- Set up a new space with default apps (deprecated - use setupNewSpaceWithTarget)
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

-- Set up a new space with explicit target space/screen (avoids getCurrentSpace issues)
function M.setupNewSpaceWithTarget(targetSpaceId, targetScreen, labelName)
  print("space-manager: Setting up new space " .. tostring(targetSpaceId) .. " on " .. targetScreen:name())
  
  -- Launch iTerm with explicit target
  M.launchAppOnTargetSpace("iTerm2", "iTerm", targetSpaceId, targetScreen, function()
    -- After iTerm, launch Chrome
    timer.doAfter(2.0, function()
      M.launchAppOnTargetSpace("Google Chrome", nil, targetSpaceId, targetScreen, function()
        -- Final step: ensure we're on the target space and show confirmation
        print("space-manager: Final switch to space " .. tostring(targetSpaceId))
        spaces.gotoSpace(targetSpaceId)
        
        timer.doAfter(0.5, function()
          -- Focus an app on the target space to ensure we're there
          local app = require("hs.application").get("iTerm2") or require("hs.application").get("iTerm")
          if app then
            app:activate()
          end
          
          print("space-manager: Setup complete for " .. (labelName or "Space"))
          alert.show("✓ " .. (labelName or "Space") .. " ready!")
        end)
      end)
    end)
  end)
end

-- Launch an app and move its window to a specific target space/screen
function M.launchAppOnTargetSpace(appName, altAppName, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  
  print("space-manager: Launching " .. appName .. " on space " .. tostring(targetSpaceId))
  
  -- Get existing windows before launch
  local app = application.get(appName)
  if not app and altAppName then
    app = application.get(altAppName)
  end
  
  local existingWindows = {}
  if app then
    for _, win in ipairs(app:allWindows()) do
      existingWindows[win:id()] = true
    end
    
    -- App is running - use Cmd+N to create new window
    app:activate()
    timer.doAfter(0.2, function()
      hs.eventtap.keyStroke({"cmd"}, "n")
      timer.doAfter(0.5, function()
        M.findAndMoveWindowToTarget(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
      end)
    end)
  else
    -- App not running - launch it
    application.launchOrFocus(appName)
    timer.doAfter(1.5, function()
      M.findAndMoveWindowToTarget(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
    end)
  end
end

-- Find a new window and move it to the target space/screen
function M.findAndMoveWindowToTarget(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  local attempts = 0
  local maxAttempts = 30
  local targetScreenUUID = targetScreen:getUUID()
  
  local function checkAndMove()
    attempts = attempts + 1
    
    local app = application.get(appName)
    if not app and altAppName then
      app = application.get(altAppName)
    end
    
    if app then
      for _, win in ipairs(app:allWindows()) do
        if not existingWindows[win:id()] and win:isStandard() then
          local winId = win:id()
          print("space-manager: Found new " .. appName .. " window " .. tostring(winId) .. " after " .. attempts .. " attempts")
          
          -- Check if window is on correct screen
          local windowScreen = win:screen()
          if windowScreen and windowScreen:getUUID() ~= targetScreenUUID then
            print("space-manager: Window on different screen, moving to target screen")
            local targetFrame = targetScreen:frame()
            win:setFrame(targetFrame)
            
            -- Wait for screen move, then go to space, then move window
            timer.doAfter(0.8, function()
              -- CRITICAL: Go to target space first (required for cross-monitor moves)
              print("space-manager: Going to space " .. tostring(targetSpaceId) .. " first")
              spaces.gotoSpace(targetSpaceId)
              
              timer.doAfter(0.5, function()
                print("space-manager: Now moving window to space " .. tostring(targetSpaceId))
                spaces.moveWindowToSpace(winId, targetSpaceId)
                
                timer.doAfter(0.3, function()
                  local freshWin = window.get(winId)
                  if freshWin then
                    freshWin:focus()
                    freshWin:raise()
                  end
                  local displayName = appName == "Google Chrome" and "Chrome" or (appName == "iTerm2" and "iTerm" or appName)
                  print("space-manager: " .. displayName .. " ready on target space")
                  if callback then callback() end
                end)
              end)
            end)
          else
            -- Same screen - still need to go to space first for reliable move
            print("space-manager: Going to space " .. tostring(targetSpaceId))
            spaces.gotoSpace(targetSpaceId)
            
            timer.doAfter(0.5, function()
              print("space-manager: Moving window to space " .. tostring(targetSpaceId))
              spaces.moveWindowToSpace(winId, targetSpaceId)
              
              timer.doAfter(0.3, function()
                win:focus()
                win:raise()
                local displayName = appName == "Google Chrome" and "Chrome" or (appName == "iTerm2" and "iTerm" or appName)
                print("space-manager: " .. displayName .. " ready on target space")
                if callback then callback() end
              end)
            end)
          end
          
          return  -- Done
        end
      end
    end
    
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkAndMove)
    else
      print("space-manager: Could not find new window for " .. appName .. " after " .. maxAttempts .. " attempts")
      if callback then callback() end
    end
  end
  
  checkAndMove()
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
