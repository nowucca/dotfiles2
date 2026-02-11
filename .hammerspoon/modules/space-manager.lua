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
-- If spaceId and scr are provided, use those (from confirmation dialog)
-- Otherwise, get current space info fresh
function M.closeCurrentSpace(providedSpaceId, providedScr)
  local spaceId = providedSpaceId
  local scr = providedScr
  
  -- If not provided, get current info
  if not spaceId or not scr then
    spaceId, scr = getCurrentSpaceInfo()
  end
  
  print("space-manager: closeCurrentSpace called")
  print("space-manager: spaceId = " .. tostring(spaceId) .. ", screen = " .. (scr and scr:name() or "nil"))
  
  if not spaceId or not scr then
    alert.show("Cannot determine current space")
    return
  end
  
  -- Get all spaces on this screen
  local screenUUID = scr:getUUID()
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  
  print("space-manager: Screen " .. scr:name() .. " has " .. #screenSpaces .. " spaces: " .. hs.json.encode(screenSpaces))
  
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
  
  -- Find an adjacent space to switch to before removing
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  local targetSpace = nil
  
  for i, sid in ipairs(screenSpaces) do
    if sid == spaceId then
      -- Prefer the space before, otherwise the space after
      if i > 1 then
        targetSpace = screenSpaces[i - 1]
      elseif i < #screenSpaces then
        targetSpace = screenSpaces[i + 1]
      end
      break
    end
  end
  
  if not targetSpace then
    print("space-manager: No adjacent space found to switch to")
    alert.show("Closed windows but couldn't remove space")
    return
  end
  
  -- Switch to the adjacent space first
  print("space-manager: Switching to adjacent space " .. tostring(targetSpace) .. " before removal")
  spaces.gotoSpace(targetSpace)
  
  -- Wait for switch, then remove the space
  timer.doAfter(0.5, function()
    print("space-manager: Now removing space " .. tostring(spaceId))
    local result = spaces.removeSpace(spaceId)
    
    if result then
      print("space-manager: Space removed successfully")
      
      -- Also remove the label from data
      if spaceLabels then
        local data = require("modules.data")
        local d = data.load()
        if d.labels and d.labels[tostring(spaceId)] then
          d.labels[tostring(spaceId)] = nil
          data.save(d)
          print("space-manager: Removed label for space " .. tostring(spaceId))
        end
      end
      
      alert.show("✓ Closed: " .. label .. " (" .. originalWindowCount .. " windows)")
    else
      print("space-manager: Failed to remove space")
      alert.show("Closed windows but couldn't remove space")
    end
  end)
end

-- Confirm before closing space
function M.confirmCloseCurrentSpace()
  -- IMPORTANT: Capture space and screen BEFORE showing dialog
  -- because the dialog will shift focus to a different screen
  local spaceId, scr = getCurrentSpaceInfo()
  
  print("space-manager: confirmCloseCurrentSpace - captured space " .. tostring(spaceId) .. " on " .. (scr and scr:name() or "nil"))
  
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
    -- Pass the captured spaceId and screen to closeCurrentSpace
    M.closeCurrentSpace(spaceId, scr)
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
    print("space-manager: Scheduling post-switch timer...")
    timer.doAfter(0.8, function()
      local ok, err = pcall(function()
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
      if not ok then
        print("space-manager: ERROR in post-switch timer: " .. tostring(err))
      end
    end)
    print("space-manager: Post-switch timer scheduled")
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

-- Launch an app and create its window ON the target space (not move after creation)
-- Key insight: windows resist being moved after creation, so we create them where we want them
function M.launchAppOnTargetSpace(appName, altAppName, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  
  print("space-manager: Launching " .. appName .. " on space " .. tostring(targetSpaceId))
  
  -- CRITICAL: Switch to target space FIRST, then create window there
  -- This avoids the "move after creation" problem entirely
  print("space-manager: Switching to target space " .. tostring(targetSpaceId) .. " before creating window")
  spaces.gotoSpace(targetSpaceId)
  
  timer.doAfter(0.5, function()
    -- Get existing windows before launch (now that we're on target space)
    local app = application.get(appName)
    if not app and altAppName then
      app = application.get(altAppName)
    end
    
    local existingWindows = {}
    if app then
      for _, win in ipairs(app:allWindows()) do
        existingWindows[win:id()] = true
      end
    end
    
    -- CHROME SPECIAL CASE: Chrome has its own window placement logic that overrides
    -- normal behavior. Using command-line launch bypasses Chrome's "switch to last active space" behavior.
    if appName == "Google Chrome" then
      print("space-manager: Chrome special case - using command line launch to avoid space switching")
      -- Use 'open -na' which creates a new window without activating existing Chrome first
      hs.task.new("/usr/bin/open", function(exitCode, stdOut, stdErr)
        print("space-manager: Chrome command line launch completed, exit code: " .. tostring(exitCode))
        timer.doAfter(1.5, function()
          M.findAndVerifyWindowAndMove(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
        end)
      end, {"-na", "Google Chrome", "--args", "--new-window"}):start()
      return
    end
    
    -- For other apps: standard approach
    if app then
      -- App is running - use Cmd+N to create new window ON THIS SPACE
      print("space-manager: App running, creating new window with Cmd+N")
      app:activate()
      timer.doAfter(0.3, function()
        hs.eventtap.keyStroke({"cmd"}, "n")
        timer.doAfter(0.8, function()
          M.findAndVerifyWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
        end)
      end)
    else
      -- App not running - launch it (window will appear on current/target space)
      print("space-manager: Launching app fresh")
      application.launchOrFocus(appName)
      timer.doAfter(2.0, function()
        M.findAndVerifyWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
      end)
    end
  end)
end

-- Find, verify, and forcefully move a window to target space if needed (for stubborn apps like Chrome)
function M.findAndVerifyWindowAndMove(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  local attempts = 0
  local maxAttempts = 40
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
          local displayName = appName == "Google Chrome" and "Chrome" or appName
          print("space-manager: Found new " .. displayName .. " window " .. tostring(winId) .. " after " .. attempts .. " attempts")
          
          -- Check where the window actually landed
          local windowSpaces = spaces.windowSpaces(winId) or {}
          local currentWindowSpace = windowSpaces[1]
          print("space-manager: " .. displayName .. " window is on space " .. tostring(currentWindowSpace) .. " (target: " .. tostring(targetSpaceId) .. ")")
          
          if currentWindowSpace == targetSpaceId then
            -- Perfect! Window is where we want it
            print("space-manager: " .. displayName .. " already on correct space!")
            win:focus()
            win:raise()
            if callback then callback() end
            return
          end
          
          -- Window is on wrong space - need to move it
          print("space-manager: " .. displayName .. " on wrong space, attempting aggressive move...")
          
          -- Step 1: Move window to target screen if needed
          local windowScreen = win:screen()
          if windowScreen and windowScreen:getUUID() ~= targetScreenUUID then
            print("space-manager: Moving window to target screen first")
            win:setFrame(targetScreen:frame())
          end
          
          -- Step 2: Go to target space
          timer.doAfter(0.3, function()
            print("space-manager: Switching to target space " .. tostring(targetSpaceId))
            spaces.gotoSpace(targetSpaceId)
            
            -- Step 3: After being on target space, try moveWindowToSpace
            timer.doAfter(0.5, function()
              print("space-manager: Attempting moveWindowToSpace for " .. displayName)
              local moveResult = spaces.moveWindowToSpace(winId, targetSpaceId)
              print("space-manager: moveWindowToSpace returned: " .. tostring(moveResult))
              
              -- Step 4: Verify and retry if needed
              timer.doAfter(0.3, function()
                local newSpaces = spaces.windowSpaces(winId) or {}
                local newSpace = newSpaces[1]
                print("space-manager: After move, " .. displayName .. " is on space " .. tostring(newSpace))
                
                if newSpace == targetSpaceId then
                  print("space-manager: " .. displayName .. " successfully moved to target space!")
                  local freshWin = window.get(winId)
                  if freshWin then
                    freshWin:focus()
                    freshWin:raise()
                  end
                  if callback then callback() end
                else
                  -- Last resort: try setFrame to pull window to current space
                  print("space-manager: Move failed, trying setFrame workaround...")
                  local freshWin = window.get(winId)
                  if freshWin then
                    -- Position window on target screen
                    local targetFrame = targetScreen:frame()
                    targetFrame.x = targetFrame.x + 50
                    targetFrame.y = targetFrame.y + 50
                    freshWin:setFrame(targetFrame)
                    
                    timer.doAfter(0.3, function()
                      -- Try move one more time
                      spaces.moveWindowToSpace(winId, targetSpaceId)
                      timer.doAfter(0.2, function()
                        local fw = window.get(winId)
                        if fw then
                          fw:focus()
                          fw:raise()
                        end
                        print("space-manager: " .. displayName .. " setup complete (best effort)")
                        if callback then callback() end
                      end)
                    end)
                  else
                    if callback then callback() end
                  end
                end
              end)
            end)
          end)
          
          return  -- Done searching
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

-- Find and verify a new window is on the target space (simpler version - window created on target space)
function M.findAndVerifyWindow(appName, altAppName, existingWindows, targetSpaceId, targetScreen, callback)
  local application = require("hs.application")
  local attempts = 0
  local maxAttempts = 30
  
  local function checkWindow()
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
          
          -- Verify it's on the target space
          local windowSpaces = spaces.windowSpaces(winId) or {}
          local currentWindowSpace = windowSpaces[1]
          print("space-manager: Window is on space " .. tostring(currentWindowSpace) .. " (target: " .. tostring(targetSpaceId) .. ")")
          
          -- Focus and raise the window
          win:focus()
          win:raise()
          
          local displayName = appName == "Google Chrome" and "Chrome" or (appName == "iTerm2" and "iTerm" or appName)
          
          if currentWindowSpace == targetSpaceId then
            print("space-manager: " .. displayName .. " ready on correct space!")
          else
            print("space-manager: WARNING: " .. displayName .. " on different space - macOS override?")
            -- Note: We accept this and continue - the window was created while we were on target space
            -- If macOS still put it elsewhere, we can't really fight it
          end
          
          if callback then callback() end
          return  -- Done
        end
      end
    end
    
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkWindow)
    else
      print("space-manager: Could not find new window for " .. appName .. " after " .. maxAttempts .. " attempts")
      if callback then callback() end
    end
  end
  
  checkWindow()
end

-- Find a new window and move it to the target space/screen (fallback for stubborn windows)
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
            -- Same screen but potentially different space - need to move
            -- First, check what space the window is currently on
            local windowSpaces = spaces.windowSpaces(winId) or {}
            local currentWindowSpace = windowSpaces[1]
            print("space-manager: Window currently on space " .. tostring(currentWindowSpace) .. ", target is " .. tostring(targetSpaceId))
            
            -- Go to target space first
            print("space-manager: Going to space " .. tostring(targetSpaceId))
            spaces.gotoSpace(targetSpaceId)
            
            timer.doAfter(0.5, function()
              print("space-manager: Moving window " .. tostring(winId) .. " to space " .. tostring(targetSpaceId))
              local moveResult = spaces.moveWindowToSpace(winId, targetSpaceId)
              print("space-manager: moveWindowToSpace returned: " .. tostring(moveResult))
              
              -- Verify the move worked
              timer.doAfter(0.3, function()
                local newSpaces = spaces.windowSpaces(winId) or {}
                local newSpace = newSpaces[1]
                print("space-manager: After move, window is on space " .. tostring(newSpace))
                
                if newSpace ~= targetSpaceId then
                  -- Move failed - try again with screen move first
                  print("space-manager: Move failed! Trying screen move workaround...")
                  local targetFrame = targetScreen:frame()
                  local freshWin = window.get(winId)
                  if freshWin then
                    freshWin:setFrame(targetFrame)
                    timer.doAfter(0.3, function()
                      spaces.gotoSpace(targetSpaceId)
                      timer.doAfter(0.3, function()
                        spaces.moveWindowToSpace(winId, targetSpaceId)
                        timer.doAfter(0.2, function()
                          local fw = window.get(winId)
                          if fw then fw:focus(); fw:raise() end
                          local displayName = appName == "Google Chrome" and "Chrome" or (appName == "iTerm2" and "iTerm" or appName)
                          print("space-manager: " .. displayName .. " ready (after retry)")
                          if callback then callback() end
                        end)
                      end)
                    end)
                  else
                    if callback then callback() end
                  end
                else
                  win:focus()
                  win:raise()
                  local displayName = appName == "Google Chrome" and "Chrome" or (appName == "iTerm2" and "iTerm" or appName)
                  print("space-manager: " .. displayName .. " ready on target space")
                  if callback then callback() end
                end
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
