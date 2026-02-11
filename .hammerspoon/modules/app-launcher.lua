-- ============================================
-- APP LAUNCHER MODULE
-- Open Chrome/iTerm windows on current space
-- Always brings new windows to the original space
-- ============================================

local M = {}

local spaces = require("hs.spaces")
local screen = require("hs.screen")
local window = require("hs.window")
local application = require("hs.application")
local timer = require("hs.timer")
local alert = require("hs.alert")
local data = require("modules.data")

-- Callback to notify menubar of updates (set by init)
M.onWindowLaunched = nil

-- Helper to get label for a space
local function getLabelForSpace(spaceId)
  local d = data.load()
  return d.spaces[tostring(spaceId)] or ("Space " .. tostring(spaceId))
end

-- ============================================
-- HELPERS
-- ============================================

-- Get the current space ID
local function getCurrentSpaceId()
  local win = window.focusedWindow()
  local scr = win and win:screen() or screen.mainScreen()
  if not scr then return nil, nil end
  local uuid = scr:getUUID()
  return spaces.activeSpaces()[uuid], uuid
end

-- Get existing window IDs for an app
local function getExistingWindowIds(app)
  local ids = {}
  if app then
    for _, win in ipairs(app:allWindows()) do
      ids[win:id()] = true
    end
  end
  return ids
end

-- ============================================
-- CHROME LAUNCHER
-- ============================================

-- Open a new Chrome window on the current space (multi-monitor aware)
function M.openChrome()
  local originalSpaceId, screenUUID = getCurrentSpaceId()
  if not originalSpaceId then
    alert.show("Cannot determine current space")
    return
  end
  
  -- Get the current screen so we can ensure window goes to the right monitor
  local currentScreen = screen.mainScreen()
  local win = window.focusedWindow()
  if win then
    currentScreen = win:screen()
  end
  
  local targetLabel = getLabelForSpace(originalSpaceId)
  print("app-launcher: Opening Chrome on space " .. tostring(originalSpaceId) .. " (" .. targetLabel .. ")")
  print("app-launcher: Target screen: " .. currentScreen:name() .. " UUID: " .. screenUUID)
  alert.show("Opening Chrome on " .. targetLabel .. "...")
  
  -- Get Chrome app and existing windows
  local chrome = application.get("Google Chrome")
  local existingWindows = getExistingWindowIds(chrome)
  
  if chrome then
    -- Chrome is running - use keyboard shortcut (Cmd+N) for new window
    chrome:activate()
    timer.doAfter(0.15, function()
      hs.eventtap.keyStroke({"cmd"}, "n")
      -- After creating window, find and move it (multi-monitor aware)
      timer.doAfter(0.5, function()
        M.findAndMoveNewWindowMultiMonitor("Google Chrome", existingWindows, originalSpaceId, currentScreen, nil)
      end)
    end)
  else
    -- Chrome not running - launch it
    application.launchOrFocus("Google Chrome")
    -- Wait for app to start and create default window
    timer.doAfter(1.0, function()
      M.findAndMoveNewWindowMultiMonitor("Google Chrome", existingWindows, originalSpaceId, currentScreen, nil)
    end)
  end
end

-- ============================================
-- ITERM LAUNCHER
-- ============================================

-- Open a new iTerm window on the current space
function M.openITerm()
  local originalSpaceId, screenUUID = getCurrentSpaceId()
  if not originalSpaceId then
    alert.show("Cannot determine current space")
    return
  end
  
  -- Get the current screen so we can ensure window goes to the right monitor
  local currentScreen = screen.mainScreen()
  local win = window.focusedWindow()
  if win then
    currentScreen = win:screen()
  end
  
  local targetLabel = getLabelForSpace(originalSpaceId)
  print("app-launcher: Opening iTerm on space " .. tostring(originalSpaceId) .. " (" .. targetLabel .. ")")
  print("app-launcher: Target screen: " .. currentScreen:name() .. " UUID: " .. screenUUID)
  alert.show("Opening iTerm on " .. targetLabel .. "...")
  
  -- Get iTerm app and existing windows
  local iterm = application.get("iTerm2") or application.get("iTerm")
  local existingWindows = getExistingWindowIds(iterm)
  
  -- Use keyboard simulation to create window (preserves shell settings)
  local app = application.get("iTerm2") or application.get("iTerm")
  if app then
    app:activate()
    -- Small delay before keystroke
    timer.doAfter(0.15, function()
      hs.eventtap.keyStroke({"cmd"}, "n")
      -- After creating window, wait longer then find and move it
      timer.doAfter(0.5, function()
        M.findAndMoveNewWindowMultiMonitor("iTerm2", existingWindows, originalSpaceId, currentScreen, "iTerm")
      end)
    end)
  else
    -- If iTerm isn't running, launch it
    application.launchOrFocus("iTerm")
    -- Wait for app to start and create default window
    timer.doAfter(1.0, function()
      M.findAndMoveNewWindowMultiMonitor("iTerm2", existingWindows, originalSpaceId, currentScreen, "iTerm")
    end)
  end
end

-- Handle multi-monitor: move window to correct screen first, then correct space
function M.findAndMoveNewWindowMultiMonitor(appName, existingWindows, targetSpaceId, targetScreen, altAppName)
  local attempts = 0
  local maxAttempts = 30
  local targetLabel = getLabelForSpace(targetSpaceId)
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
          print("app-launcher: Found new window " .. tostring(winId) .. " after " .. attempts .. " attempts")
          
          -- Check what screen and space the window is on
          local windowScreen = win:screen()
          local windowSpaces = spaces.windowSpaces(win) or {}
          print("app-launcher: Window on screen: " .. (windowScreen and windowScreen:name() or "nil"))
          print("app-launcher: Window on spaces: " .. hs.json.encode(windowSpaces))
          print("app-launcher: Target screen: " .. targetScreen:name() .. ", target space: " .. tostring(targetSpaceId) .. " (" .. targetLabel .. ")")
          
          -- If window is on different screen, move it to target screen first
          if windowScreen and windowScreen:getUUID() ~= targetScreenUUID then
            print("app-launcher: Window on different screen, moving to target screen first")
            -- Move window to the target screen by setting its frame
            local targetFrame = targetScreen:frame()
            win:setFrame(targetFrame)
            
            -- Give it more time to settle on new screen
            timer.doAfter(0.8, function()
              -- Get a fresh reference to the window
              local freshWin = window.get(winId)
              if freshWin then
                print("app-launcher: Window now on screen: " .. (freshWin:screen() and freshWin:screen():name() or "unknown"))
                
                -- First, go to the target space (so the move will work)
                print("app-launcher: Going to target space " .. tostring(targetSpaceId) .. " first")
                spaces.gotoSpace(targetSpaceId)
                
                timer.doAfter(0.5, function()
                  -- Now move the window to this space
                  print("app-launcher: Now moving window to space " .. tostring(targetSpaceId))
                  local moveResult = spaces.moveWindowToSpace(winId, targetSpaceId)
                  print("app-launcher: Move result: " .. tostring(moveResult))
                  
                  -- Check what space the window is on now
                  local windowSpacesNow = spaces.windowSpaces(winId) or {}
                  print("app-launcher: Window now on spaces: " .. hs.json.encode(windowSpacesNow))
                  
                  timer.doAfter(0.3, function()
                    -- Try to focus
                    local winToFocus = window.get(winId)
                    if winToFocus then
                      print("app-launcher: Focusing window")
                      winToFocus:focus()
                      -- Raise it too
                      winToFocus:raise()
                      -- Show app name in alert
                      local displayName = appName == "Google Chrome" and "Chrome" or appName
                      alert.show(displayName .. " ready")
                      -- Refresh menubar after a brief delay
                      timer.doAfter(0.2, function()
                        if M.onWindowLaunched then M.onWindowLaunched() end
                      end)
                    else
                      print("app-launcher: Could not get window to focus")
                      local displayName = appName == "Google Chrome" and "Chrome" or appName
                      alert.show(displayName .. " opened")
                    end
                  end)
                end)
              else
                print("app-launcher: Lost window reference after screen move")
                spaces.gotoSpace(targetSpaceId)
                alert.show("iTerm opened (check spaces)")
              end
            end)
          else
            -- Same screen, just move to space
            print("app-launcher: Same screen, moving to space " .. tostring(targetSpaceId))
            spaces.moveWindowToSpace(winId, targetSpaceId)
            
            timer.doAfter(0.3, function()
              M.gotoSpaceAndFocus(targetSpaceId, win, targetLabel)
            end)
          end
          
          return  -- Done
        end
      end
    end
    
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkAndMove)
    else
      print("app-launcher: Could not find new window after " .. maxAttempts .. " attempts")
      M.forceGoToSpace(targetSpaceId)
    end
  end
  
  checkAndMove()
end

-- Go to space and focus window
function M.gotoSpaceAndFocus(targetSpaceId, win, targetLabel)
  print("app-launcher: Going to space " .. tostring(targetSpaceId) .. " (" .. (targetLabel or "") .. ")")
  spaces.gotoSpace(targetSpaceId)
  
  timer.doAfter(0.5, function()
    local currentSpace = getCurrentSpaceId()
    if currentSpace == targetSpaceId then
      print("app-launcher: On target space, focusing window")
      win:focus()
      alert.show("iTerm ready")
      -- Refresh menubar
      timer.doAfter(0.2, function()
        if M.onWindowLaunched then M.onWindowLaunched() end
      end)
    else
      print("app-launcher: Not on target space (current=" .. tostring(currentSpace) .. "), trying again")
      spaces.gotoSpace(targetSpaceId)
      timer.doAfter(0.3, function()
        win:focus()
        alert.show("iTerm ready")
        -- Refresh menubar
        timer.doAfter(0.2, function()
          if M.onWindowLaunched then M.onWindowLaunched() end
        end)
      end)
    end
  end)
end

-- Find new window and move it to target space, then switch back
function M.findAndMoveNewWindow(appName, existingWindows, targetSpaceId, altAppName)
  local attempts = 0
  local maxAttempts = 30  -- 3 seconds total
  local targetLabel = getLabelForSpace(targetSpaceId)
  
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
          print("app-launcher: Found new window " .. tostring(winId) .. " after " .. attempts .. " attempts")
          
          -- Check what space the window is currently on
          local windowSpaces = spaces.windowSpaces(win) or {}
          print("app-launcher: Window currently on spaces: " .. hs.json.encode(windowSpaces))
          
          -- Move the window using its ID (integer)
          print("app-launcher: Moving window " .. tostring(winId) .. " to space " .. tostring(targetSpaceId) .. " (" .. targetLabel .. ")")
          local moveResult = spaces.moveWindowToSpace(winId, targetSpaceId)
          print("app-launcher: First move result: " .. tostring(moveResult))
          
          -- Give it time, then verify and retry if needed
          timer.doAfter(0.5, function()
            -- Check where window is now
            local newWindowSpaces = spaces.windowSpaces(winId) or {}
            print("app-launcher: Window now on spaces: " .. hs.json.encode(newWindowSpaces))
            
            -- If not on target space, try again
            local onTarget = false
            for _, sp in ipairs(newWindowSpaces) do
              if sp == targetSpaceId then onTarget = true break end
            end
            
            if not onTarget then
              print("app-launcher: Window not on target, trying again")
              spaces.moveWindowToSpace(winId, targetSpaceId)
            end
            
            -- Now switch to the space
            timer.doAfter(0.3, function()
              M.switchToSpaceThenVerifyWindow(targetSpaceId, win, targetLabel)
            end)
          end)
          
          return  -- Done with this function
        end
      end
    end
    
    -- Keep trying
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkAndMove)
    else
      print("app-launcher: Could not find new window after " .. maxAttempts .. " attempts")
      M.forceGoToSpace(targetSpaceId)
    end
  end
  
  checkAndMove()
end

-- Switch to space first, then verify window is there before focusing
function M.switchToSpaceThenVerifyWindow(targetSpaceId, win, targetLabel)
  local attempts = 0
  local maxAttempts = 5
  targetLabel = targetLabel or getLabelForSpace(targetSpaceId)
  
  local function trySwitch()
    attempts = attempts + 1
    print("app-launcher: Switching to space " .. tostring(targetSpaceId) .. " (" .. targetLabel .. ") (attempt " .. attempts .. ")")
    
    -- Go to the target space
    spaces.gotoSpace(targetSpaceId)
    
    timer.doAfter(0.5, function()
      -- Check if we're on the right space
      local currentSpace = getCurrentSpaceId()
      print("app-launcher: Current space is " .. tostring(currentSpace) .. ", target is " .. tostring(targetSpaceId))
      
      if currentSpace == targetSpaceId then
        print("app-launcher: Successfully on target space")
        
        -- Now check if the window is actually on this space
        local windowsOnSpace = spaces.windowsForSpace(targetSpaceId) or {}
        local windowIsHere = false
        for _, winId in ipairs(windowsOnSpace) do
          if winId == win:id() then
            windowIsHere = true
            break
          end
        end
        
        if windowIsHere then
          print("app-launcher: Window verified on target space, focusing")
          win:focus()
          alert.show("iTerm ready")
        else
          print("app-launcher: Window NOT on target space, trying to move again")
          -- Try moving it again
          spaces.moveWindowToSpace(win, targetSpaceId)
          timer.doAfter(0.3, function()
            win:focus()
            alert.show("iTerm ready (moved)")
          end)
        end
      elseif attempts < maxAttempts then
        print("app-launcher: Not on target space yet")
        trySwitch()
      else
        print("app-launcher: Giving up on space switch")
        alert.show("iTerm opened on wrong space - use ⌘⌃Space to switch")
      end
    end)
  end
  
  trySwitch()
end

-- Force go to a space (used when no window found)
function M.forceGoToSpace(targetSpaceId)
  spaces.gotoSpace(targetSpaceId)
  timer.doAfter(0.3, function()
    spaces.gotoSpace(targetSpaceId)
  end)
end

-- ============================================
-- WINDOW MOVEMENT
-- ============================================

-- Ensure we switch back to the target space (with retries)
local function ensureOnSpace(targetSpaceId, callback, maxRetries)
  maxRetries = maxRetries or 3
  local retries = 0
  
  local function trySwitch()
    spaces.gotoSpace(targetSpaceId)
    retries = retries + 1
    
    -- Check after a brief delay if we're on the right space
    timer.doAfter(0.3, function()
      local win = window.focusedWindow()
      local scr = win and win:screen() or screen.mainScreen()
      if scr then
        local uuid = scr:getUUID()
        local currentSpaceId = spaces.activeSpaces()[uuid]
        
        if currentSpaceId == targetSpaceId then
          print("app-launcher: Successfully on target space " .. tostring(targetSpaceId))
          if callback then callback() end
        elseif retries < maxRetries then
          print("app-launcher: Not on target space yet, retry " .. retries)
          trySwitch()
        else
          print("app-launcher: Failed to switch to target space after " .. maxRetries .. " retries")
          if callback then callback() end
        end
      else
        if callback then callback() end
      end
    end)
  end
  
  trySwitch()
end

-- Wait for a new window to appear, then move it to the target space
-- Retries multiple times to handle timing issues
function M.waitAndMoveNewWindow(appName, existingWindows, targetSpaceId, screenUUID, altAppName)
  local attempts = 0
  local maxAttempts = 20  -- 2 seconds total (20 * 0.1s)
  local newWindow = nil
  
  local function checkForNewWindow()
    attempts = attempts + 1
    
    local app = application.get(appName)
    if not app and altAppName then
      app = application.get(altAppName)
    end
    
    if app then
      for _, win in ipairs(app:allWindows()) do
        if not existingWindows[win:id()] and win:isStandard() then
          newWindow = win
          print("app-launcher: Found new window " .. tostring(win:id()) .. " after " .. attempts .. " attempts")
          
          -- Move the window to the target space
          spaces.moveWindowToSpace(win, targetSpaceId)
          print("app-launcher: Moved window to space " .. tostring(targetSpaceId))
          
          -- Switch back to the original space (with retries to ensure we get there)
          timer.doAfter(0.2, function()
            ensureOnSpace(targetSpaceId, function()
              -- Focus the new window after we're on the right space
              if newWindow then
                newWindow:focus()
                print("app-launcher: Focused window")
              end
            end)
          end)
          
          return  -- Success!
        end
      end
    end
    
    -- Retry if not found yet
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkForNewWindow)
    else
      print("app-launcher: Could not find new window after " .. maxAttempts .. " attempts")
      -- Still try to go back to original space
      ensureOnSpace(targetSpaceId, nil)
    end
  end
  
  -- Start checking after a brief initial delay
  timer.doAfter(0.1, checkForNewWindow)
end

-- ============================================
-- GENERIC LAUNCHER
-- ============================================

-- Show a chooser to pick which app to launch
function M.showLauncher()
  local chooser = require("hs.chooser")
  
  local choices = {
    { text = "🌐 Chrome", subText = "Open new Chrome window on this space", app = "chrome" },
    { text = "💻 iTerm", subText = "Open new iTerm window on this space", app = "iterm" },
  }
  
  local ch = chooser.new(function(choice)
    if not choice then return end
    if choice.app == "chrome" then
      M.openChrome()
    elseif choice.app == "iterm" then
      M.openITerm()
    end
  end)
  
  ch:choices(choices)
  ch:placeholderText("Launch app on current space...")
  ch:show()
end

return M
