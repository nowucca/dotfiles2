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
-- SAFE OPERATION HELPERS
-- ============================================

-- Safe wrapper for operations that might fail with stale references
local function safeCall(fn, errorContext)
  local ok, err = pcall(fn)
  if not ok then
    print("space-manager: Error in " .. (errorContext or "operation") .. ": " .. tostring(err))
  end
  return ok
end

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

-- Get display name for an app
local function getDisplayName(appName)
  if appName == "Google Chrome" then return "Chrome" end
  if appName == "iTerm2" then return "iTerm" end
  return appName
end

-- ============================================
-- CLOSE SPACE
-- ============================================

function M.closeCurrentSpace(providedSpaceId, providedScr)
  local spaceId = providedSpaceId
  local scr = providedScr
  
  if not spaceId or not scr then
    spaceId, scr = getCurrentSpaceInfo()
  end
  
  print("space-manager: closeCurrentSpace - spaceId=" .. tostring(spaceId) .. ", screen=" .. (scr and scr:name() or "nil"))
  
  if not spaceId or not scr then
    alert.show("Cannot determine current space")
    return
  end
  
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  
  if #screenSpaces <= 1 then
    alert.show("Cannot close: only one space on this screen")
    return
  end
  
  local label = spaceLabels and spaceLabels.getCurrentLabel() or ("Space " .. tostring(spaceId))
  local windows = getWindowsOnSpace(spaceId)
  local windowCount = #windows
  
  print("space-manager: Closing " .. windowCount .. " windows on " .. label)
  
  -- Close all windows
  for _, win in ipairs(windows) do
    safeCall(function() win:close() end, "closing window")
  end
  
  -- Wait for windows to close, then remove the space
  timer.doAfter(0.5, function()
    local remainingWindows = getWindowsOnSpace(spaceId)
    if #remainingWindows > 0 then
      timer.doAfter(1.0, function()
        M.removeSpaceIfEmpty(spaceId, scr, label, windowCount)
      end)
    else
      M.removeSpaceIfEmpty(spaceId, scr, label, windowCount)
    end
  end)
end

function M.removeSpaceIfEmpty(spaceId, scr, label, originalWindowCount)
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  local targetSpace = nil
  
  for i, sid in ipairs(screenSpaces) do
    if sid == spaceId then
      targetSpace = (i > 1) and screenSpaces[i - 1] or screenSpaces[i + 1]
      break
    end
  end
  
  if not targetSpace then
    alert.show("Closed windows but couldn't remove space")
    return
  end
  
  safeCall(function() spaces.gotoSpace(targetSpace) end, "gotoSpace")
  
  timer.doAfter(0.5, function()
    local result = spaces.removeSpace(spaceId)
    
    if result then
      -- Remove label from data
      if spaceLabels then
        safeCall(function()
          local data = require("modules.data")
          local d = data.load()
          if d.labels and d.labels[tostring(spaceId)] then
            d.labels[tostring(spaceId)] = nil
            data.save(d)
          end
        end, "removing label")
      end
      alert.show("✓ Closed: " .. label .. " (" .. originalWindowCount .. " windows)")
    else
      alert.show("Closed windows but couldn't remove space")
    end
  end)
end

function M.confirmCloseCurrentSpace()
  local spaceId, scr = getCurrentSpaceInfo()
  
  if not spaceId or not scr then
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
    M.closeCurrentSpace(spaceId, scr)
  end
end

-- ============================================
-- CREATE SPACE
-- ============================================

function M.createNewSpace()
  local _, scr = getCurrentSpaceInfo()
  scr = scr or screen.mainScreen()
  
  if not scr then
    alert.show("No screen found")
    return
  end
  
  print("space-manager: Creating new space on " .. scr:name())
  M.promptForLabelThenCreate(scr)
end

function M.promptForLabelThenCreate(scr)
  local button, labelName = dialog.textPrompt(
    "New Space",
    "Enter a label for the new space:",
    "",
    "Create",
    "Cancel"
  )
  
  if button ~= "Create" then return end
  
  alert.show("Creating: " .. (labelName or "New Space") .. "...")
  
  local oldSpaceIds = getSpaceIdsForScreen(scr)
  local result = spaces.addSpaceToScreen(scr, true)
  
  if not result then
    alert.show("Failed to create new space")
    return
  end
  
  timer.doAfter(0.5, function()
    local newSpaceId = findNewSpaceId(oldSpaceIds, scr)
    
    if not newSpaceId then
      alert.show("Created space but couldn't find it")
      return
    end
    
    print("space-manager: Found new space ID: " .. tostring(newSpaceId))
    
    -- Set the label
    if labelName and labelName ~= "" and spaceLabels then
      safeCall(function()
        local data = require("modules.data")
        local d = data.load()
        data.setLabelForSpace(d, tostring(newSpaceId), labelName)
        data.save(d)
      end, "setting label")
    end
    
    -- Switch to the new space
    safeCall(function() spaces.gotoSpace(newSpaceId) end, "gotoSpace")
    
    -- Launch apps after switch completes
    timer.doAfter(0.8, function()
      safeCall(function()
        M.setupNewSpaceWithTarget(newSpaceId, scr, labelName)
      end, "setupNewSpaceWithTarget")
    end)
  end)
end

function M.setupNewSpaceWithTarget(targetSpaceId, targetScreen, labelName)
  print("space-manager: Setting up space " .. tostring(targetSpaceId))
  
  -- Launch iTerm first
  M.launchAppOnTargetSpace("iTerm2", "iTerm", targetSpaceId, targetScreen, function()
    -- Then Chrome
    timer.doAfter(2.0, function()
      M.launchAppOnTargetSpace("Google Chrome", nil, targetSpaceId, targetScreen, function()
        -- Final switch and confirmation
        safeCall(function() spaces.gotoSpace(targetSpaceId) end, "final gotoSpace")
        
        timer.doAfter(0.5, function()
          safeCall(function()
            local app = require("hs.application").get("iTerm2") or require("hs.application").get("iTerm")
            if app then app:activate() end
          end, "activating iTerm")
          
          alert.show("✓ " .. (labelName or "Space") .. " ready!")
        end)
      end)
    end)
  end)
end

-- ============================================
-- APP LAUNCHING (with robust error handling)
-- ============================================

function M.launchAppOnTargetSpace(appName, altAppName, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  local displayName = getDisplayName(appName)
  
  print("space-manager: Launching " .. displayName .. " on space " .. tostring(targetSpaceId))
  
  -- Switch to target space first
  safeCall(function() spaces.gotoSpace(targetSpaceId) end, "gotoSpace")
  
  timer.doAfter(0.5, function()
    local app = application.get(appName) or (altAppName and application.get(altAppName))
    
    local existingWindows = {}
    if app then
      for _, win in ipairs(app:allWindows()) do
        existingWindows[win:id()] = true
      end
    end
    
    -- Use AppleScript for known apps to avoid space-switching behavior
    -- app:activate() switches macOS to whatever space the app is on,
    -- causing new windows to appear on the wrong space
    if appName == "Google Chrome" then
      print("space-manager: Chrome - using AppleScript for new window")
      hs.osascript.applescript([[
        tell application "Google Chrome"
          make new window
        end tell
      ]])
      timer.doAfter(1.0, function()
        M.findAndMoveWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
      end)
      return
    end

    if appName == "iTerm2" or appName == "iTerm" then
      print("space-manager: iTerm - using AppleScript for new window")
      hs.osascript.applescript([[
        tell application "iTerm2"
          create window with default profile
        end tell
      ]])
      timer.doAfter(1.0, function()
        M.findAndMoveWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
      end)
      return
    end

    -- Standard apps: activate and Cmd+N
    if app then
      safeCall(function() app:activate() end, "activating app")
      timer.doAfter(0.3, function()
        hs.eventtap.keyStroke({"cmd"}, "n")
        timer.doAfter(0.8, function()
          M.findAndMoveWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
        end)
      end)
    else
      -- App not running - launch fresh
      application.launchOrFocus(appName)
      timer.doAfter(2.0, function()
        M.findAndMoveWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
      end)
    end
  end)
end

-- Unified window finder with aggressive move support
function M.findAndMoveWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  local attempts = 0
  local maxAttempts = 40
  local targetScreenUUID = targetScreen:getUUID()
  local displayName = getDisplayName(appName)
  
  local function checkAndMove()
    attempts = attempts + 1
    
    local app = application.get(appName) or (altAppName and application.get(altAppName))
    
    if app then
      -- First try focusedWindow (works better with Stage Manager)
      if attempts == 1 then
        local focused = window.focusedWindow()
        if focused then
          local focusedApp = focused:application()
          if focusedApp and focusedApp:name() == appName then
            local focusedId = focused:id()
            if not existingWindows[focusedId] and focused:isStandard() then
              print("space-manager: Found " .. displayName .. " via focusedWindow: " .. tostring(focusedId))
              M.moveWindowToTarget(focused, focusedId, targetSpaceId, targetScreen, targetScreenUUID, displayName, callback)
              return
            end
          end
        end
      end
      
      -- Fall back to allWindows enumeration
      for _, win in ipairs(app:allWindows()) do
        if not existingWindows[win:id()] and win:isStandard() then
          local winId = win:id()
          print("space-manager: Found " .. displayName .. " window " .. tostring(winId) .. " at attempt " .. attempts)
          M.moveWindowToTarget(win, winId, targetSpaceId, targetScreen, targetScreenUUID, displayName, callback)
          return
        end
      end
    end
    
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkAndMove)
    else
      print("space-manager: Could not find " .. displayName .. " window after " .. maxAttempts .. " attempts")
      if callback then callback() end
    end
  end
  
  checkAndMove()
end

-- Move a window to the target space/screen with error handling
function M.moveWindowToTarget(win, winId, targetSpaceId, targetScreen, targetScreenUUID, displayName, callback)
  local windowSpaces = spaces.windowSpaces(winId) or {}
  local currentSpace = windowSpaces[1]
  local windowScreen = win:screen()
  
  print("space-manager: " .. displayName .. " on space " .. tostring(currentSpace) .. " (target: " .. tostring(targetSpaceId) .. ")")
  
  local onCorrectSpace = currentSpace == targetSpaceId
  local onCorrectScreen = windowScreen and windowScreen:getUUID() == targetScreenUUID
  
  -- Already in the right place
  if onCorrectSpace and onCorrectScreen then
    print("space-manager: " .. displayName .. " already on correct space/screen")
    safeCall(function() win:focus(); win:raise() end, "focusing window")
    if callback then callback() end
    return
  end
  
  -- Need to move
  print("space-manager: Moving " .. displayName .. " to target...")
  
  -- Step 1: Move to target screen if needed
  if not onCorrectScreen then
    safeCall(function()
      win:setFrame(targetScreen:frame())
    end, "setFrame to target screen")
  end
  
  -- Step 2: Go to target space
  timer.doAfter(0.3, function()
    safeCall(function() spaces.gotoSpace(targetSpaceId) end, "gotoSpace")
    
    -- Step 3: Move window to space
    timer.doAfter(0.5, function()
      safeCall(function() spaces.moveWindowToSpace(winId, targetSpaceId) end, "moveWindowToSpace")
      
      -- Step 4: Verify and focus
      timer.doAfter(0.3, function()
        local newSpaces = spaces.windowSpaces(winId) or {}
        local newSpace = newSpaces[1]
        
        if newSpace == targetSpaceId then
          print("space-manager: " .. displayName .. " moved successfully")
        else
          -- Retry with setFrame workaround
          print("space-manager: " .. displayName .. " move failed, trying workaround...")
          safeCall(function()
            local fw = window.get(winId)
            if fw then
              local frame = targetScreen:frame()
              frame.x = frame.x + 50
              frame.y = frame.y + 50
              fw:setFrame(frame)
            end
          end, "setFrame workaround")
          
          timer.doAfter(0.3, function()
            safeCall(function() spaces.moveWindowToSpace(winId, targetSpaceId) end, "retry moveWindowToSpace")
          end)
        end
        
        -- Focus the window
        timer.doAfter(0.2, function()
          safeCall(function()
            local fw = window.get(winId)
            if fw then fw:focus(); fw:raise() end
          end, "final focus")
          
          print("space-manager: " .. displayName .. " setup complete")
          if callback then callback() end
        end)
      end)
    end)
  end)
end

-- ============================================
-- INITIALIZATION
-- ============================================

function M.init(deps)
  spaceLabels = deps.spaceLabels
  appLauncher = deps.appLauncher
end

return M
