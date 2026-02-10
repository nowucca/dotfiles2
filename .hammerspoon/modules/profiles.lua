-- ============================================
-- PROFILES MODULE
-- Save/restore space configurations (per-space)
-- ============================================

local M = {}

local json = require("hs.json")
local fs = require("hs.fs")
local spaces = require("hs.spaces")
local screen = require("hs.screen")
local window = require("hs.window")
local application = require("hs.application")
local timer = require("hs.timer")
local alert = require("hs.alert")
local chooser = require("hs.chooser")
local dialog = require("hs.dialog")

local data = require("modules.data")
local spaceLabels = require("modules.space-labels")

local profilesDir = hs.configdir .. "/space-profiles"

-- ============================================
-- HELPERS
-- ============================================

local function ensureProfilesDir()
  fs.mkdir(profilesDir)
end

local function getProfilePath(name)
  return profilesDir .. "/" .. name .. ".json"
end

local function getCurrentSpaceId()
  local win = window.focusedWindow()
  local scr = win and win:screen() or screen.mainScreen()
  if not scr then return nil end
  local uuid = scr:getUUID()
  return spaces.activeSpaces()[uuid]
end

-- Get current space info including screen reference
local function getCurrentSpaceInfo()
  local win = window.focusedWindow()
  local scr = win and win:screen() or screen.mainScreen()
  if not scr then return nil, nil end
  local uuid = scr:getUUID()
  local spaceId = spaces.activeSpaces()[uuid]
  return spaceId, scr
end

-- Move window to correct screen and space (handles multi-monitor)
local function moveWindowToScreenAndSpace(win, targetScreen, targetSpaceId)
  local winId = win:id()
  local windowScreen = win:screen()
  local targetScreenUUID = targetScreen:getUUID()
  
  -- If window is on different screen, move it to target screen first
  if windowScreen and windowScreen:getUUID() ~= targetScreenUUID then
    print("profiles: Window on different screen, moving to target screen first")
    local targetFrame = targetScreen:frame()
    win:setFrame(targetFrame)
    
    -- Wait for window to settle on new screen, then move to space
    timer.doAfter(0.5, function()
      local freshWin = window.get(winId)
      if freshWin then
        -- Go to target space first
        spaces.gotoSpace(targetSpaceId)
        
        timer.doAfter(0.3, function()
          -- Now move window to space
          spaces.moveWindowToSpace(winId, targetSpaceId)
          
          timer.doAfter(0.2, function()
            local finalWin = window.get(winId)
            if finalWin then
              finalWin:focus()
            end
          end)
        end)
      end
    end)
  else
    -- Same screen, just move to space directly
    spaces.moveWindowToSpace(winId, targetSpaceId)
    timer.doAfter(0.2, function()
      win:focus()
    end)
  end
end

-- ============================================
-- SAVE CURRENT SPACE CONFIG
-- ============================================

-- Get list of apps with windows on current space
function M.getAppsOnCurrentSpace()
  local spaceId = getCurrentSpaceId()
  if not spaceId then return {} end
  
  local apps = {}
  local seenApps = {}
  
  local winIds = spaces.windowsForSpace(spaceId) or {}
  for _, winId in ipairs(winIds) do
    local win = window.get(winId)
    if win and win:isStandard() then
      local app = win:application()
      if app then
        local appName = app:name()
        -- Avoid duplicates
        if appName and not seenApps[appName] then
          seenApps[appName] = true
          table.insert(apps, {
            name = appName,
            bundleID = app:bundleID()
          })
        end
      end
    end
  end
  
  return apps
end

-- Save current space as a profile
function M.saveCurrentSpace(profileName)
  if not profileName or profileName == "" then return end
  
  ensureProfilesDir()
  
  local label = spaceLabels.getCurrentLabel()
  local apps = M.getAppsOnCurrentSpace()
  
  local profile = {
    name = profileName,
    label = label,
    savedAt = os.time(),
    apps = apps
  }
  
  local path = getProfilePath(profileName)
  local f = io.open(path, "w")
  if f then
    f:write(json.encode(profile, true))
    f:close()
    alert.show("Saved: " .. profileName .. " (" .. #apps .. " apps)")
  else
    alert.show("Failed to save profile")
  end
end

-- Prompt user to save current space
function M.promptSaveCurrentSpace()
  local currentLabel = spaceLabels.getCurrentLabel() or ""
  
  local button, name = dialog.textPrompt(
    "Save Space Profile",
    "Profile name (used as filename):",
    currentLabel,
    "Save",
    "Cancel"
  )
  
  if button == "Save" and name and name ~= "" then
    M.saveCurrentSpace(name)
  end
end

-- ============================================
-- RESTORE SPACE CONFIG
-- ============================================

-- List all saved profiles
function M.listProfiles()
  ensureProfilesDir()
  local profiles = {}
  
  local iter, dir = fs.dir(profilesDir)
  if iter then
    for file in iter, dir do
      if file:match("%.json$") then
        local name = file:gsub("%.json$", "")
        local path = getProfilePath(name)
        local f = io.open(path, "r")
        if f then
          local content = f:read("*a")
          f:close()
          local profile = json.decode(content)
          if profile then
            profile.filename = name
            table.insert(profiles, profile)
          end
        end
      end
    end
  end
  
  -- Sort by name
  table.sort(profiles, function(a, b)
    return string.lower(a.name or "") < string.lower(b.name or "")
  end)
  
  return profiles
end

-- Launch an app and move its new window to the current space
-- This handles the case where the app is already running on another space
-- Uses multi-monitor aware window movement
function M.launchAppToCurrentSpace(appName, bundleID, targetSpaceId, targetScreen)
  -- Use provided targets or get current space info
  local spaceId, scr
  if targetSpaceId and targetScreen then
    spaceId = targetSpaceId
    scr = targetScreen
  else
    spaceId, scr = getCurrentSpaceInfo()
  end
  
  if not spaceId or not scr then 
    print("profiles: No current space ID or screen")
    return 
  end
  
  print("profiles: Launching " .. appName .. " (bundle: " .. tostring(bundleID) .. ") to space " .. tostring(spaceId) .. " on " .. scr:name())
  
  -- Special handling for iTerm - use keyboard simulation to preserve shell settings
  if appName == "iTerm2" or appName == "iTerm" then
    M.createiTermWindowOnCurrentSpace(spaceId, scr)
    return
  end
  
  -- Get existing windows before launch
  local app = bundleID and application.get(bundleID) or application.get(appName)
  local existingWindows = {}
  local wasRunning = (app ~= nil)
  
  if app then
    for _, win in ipairs(app:allWindows()) do
      existingWindows[win:id()] = true
    end
    print("profiles: App already running with " .. #app:allWindows() .. " windows")
  end
  
  -- Launch using bundleID first (more reliable), fall back to name
  local launched = false
  
  if bundleID then
    launched = application.launchOrFocusByBundleID(bundleID)
    print("profiles: launchOrFocusByBundleID returned " .. tostring(launched))
  end
  
  if not launched then
    launched = application.launchOrFocus(appName)
    print("profiles: launchOrFocus returned " .. tostring(launched))
  end
  
  if not launched then
    print("profiles: Failed to launch " .. appName)
    alert.show("Failed to launch: " .. appName)
    return
  end
  
  print("profiles: App launched/focused, waiting for windows...")
  
  -- Wait for windows to appear, then move new ones to current space (multi-monitor aware)
  timer.doAfter(2.0, function()
    local app = bundleID and application.get(bundleID) or application.get(appName)
    if app then
      local moved = 0
      for _, win in ipairs(app:allWindows()) do
        -- If this is a new window (wasn't there before), move it
        if not existingWindows[win:id()] and win:isStandard() then
          print("profiles: Moving window " .. tostring(win:id()) .. " to space " .. tostring(spaceId))
          moveWindowToScreenAndSpace(win, scr, spaceId)
          moved = moved + 1
        end
      end
      print("profiles: Moved " .. moved .. " windows")
      
      -- If app was already running and no new windows, might need to create one
      if wasRunning and moved == 0 then
        print("profiles: App was running but no new windows created")
        -- For some apps, focusing creates a window. For others we may need special handling.
      end
    else
      print("profiles: App not found after launch")
    end
  end)
end

-- Create a new iTerm window on the current space (multi-monitor aware)
-- Uses keyboard simulation to preserve shell settings (colored prompt, etc.)
function M.createiTermWindowOnCurrentSpace(spaceId, targetScreen)
  -- Get existing windows before creating new one
  local iterm = application.get("iTerm2") or application.get("iTerm")
  local existingWindows = {}
  
  if iterm then
    for _, win in ipairs(iterm:allWindows()) do
      existingWindows[win:id()] = true
    end
    
    -- Use keyboard simulation (preserves shell settings)
    iterm:activate()
    timer.doAfter(0.15, function()
      hs.eventtap.keyStroke({"cmd"}, "n")
      
      -- Wait for window then move it
      timer.doAfter(0.5, function()
        M.findAndMoveNewWindow("iTerm2", existingWindows, spaceId, targetScreen, "iTerm")
      end)
    end)
  else
    -- iTerm not running, launch it
    application.launchOrFocus("iTerm")
    timer.doAfter(1.0, function()
      M.findAndMoveNewWindow("iTerm2", existingWindows, spaceId, targetScreen, "iTerm")
    end)
  end
end

-- Find a new window and move it to the target screen/space (multi-monitor aware)
function M.findAndMoveNewWindow(appName, existingWindows, targetSpaceId, targetScreen, altAppName)
  local attempts = 0
  local maxAttempts = 30
  
  local function checkAndMove()
    attempts = attempts + 1
    
    local app = application.get(appName)
    if not app and altAppName then
      app = application.get(altAppName)
    end
    
    if app then
      for _, win in ipairs(app:allWindows()) do
        if not existingWindows[win:id()] and win:isStandard() then
          print("profiles: Found new window " .. tostring(win:id()) .. " after " .. attempts .. " attempts")
          
          -- Use multi-monitor aware movement
          moveWindowToScreenAndSpace(win, targetScreen, targetSpaceId)
          return  -- Done
        end
      end
    end
    
    if attempts < maxAttempts then
      timer.doAfter(0.1, checkAndMove)
    else
      print("profiles: Could not find new window after " .. maxAttempts .. " attempts")
      -- Still try to go to target space
      spaces.gotoSpace(targetSpaceId)
    end
  end
  
  checkAndMove()
end

-- Restore a profile to the current space
function M.restoreProfile(profileName)
  local path = getProfilePath(profileName)
  local f = io.open(path, "r")
  if not f then
    alert.show("Profile not found: " .. profileName)
    return
  end
  
  local content = f:read("*a")
  f:close()
  local profile = json.decode(content)
  
  if not profile then
    alert.show("Invalid profile")
    return
  end
  
  -- Capture target space/screen BEFORE any launches change focus
  local targetSpaceId, targetScreen = getCurrentSpaceInfo()
  if not targetSpaceId or not targetScreen then
    alert.show("Cannot determine current space")
    return
  end
  
  print("profiles: Restoring profile '" .. profile.name .. "' to space " .. tostring(targetSpaceId) .. " on " .. targetScreen:name())
  
  -- Apply label to current space if profile has one
  if profile.label then
    spaceLabels.set(profile.label)
  end
  
  alert.show("Restoring: " .. profile.name .. " (" .. #(profile.apps or {}) .. " apps)")
  
  -- Launch each app, passing the captured target space/screen
  for i, appInfo in ipairs(profile.apps or {}) do
    -- Stagger launches to avoid overwhelming the system
    -- Use longer delay to account for multi-monitor window movement
    timer.doAfter(i * 2.5, function()
      M.launchAppToCurrentSpace(appInfo.name, appInfo.bundleID, targetSpaceId, targetScreen)
    end)
  end
end

-- Show chooser to restore a profile
function M.showRestoreChooser()
  local profiles = M.listProfiles()
  
  if #profiles == 0 then
    alert.show("No saved profiles")
    return
  end
  
  local choices = {}
  for _, profile in ipairs(profiles) do
    local daysAgo = math.floor((os.time() - (profile.savedAt or 0)) / 86400)
    local appCount = #(profile.apps or {})
    
    table.insert(choices, {
      text = profile.name,
      subText = appCount .. " apps | " .. 
                (profile.label and ("Label: " .. profile.label) or "No label") ..
                " | Saved: " .. data.formatDaysAgo(profile.savedAt),
      profileName = profile.filename
    })
  end
  
  local ch = chooser.new(function(choice)
    if not choice then return end
    M.restoreProfile(choice.profileName)
  end)
  
  ch:choices(choices)
  ch:placeholderText("Select profile to restore...")
  ch:show()
end

-- Show chooser to delete a profile
function M.showDeleteChooser()
  local profiles = M.listProfiles()
  
  if #profiles == 0 then
    alert.show("No saved profiles")
    return
  end
  
  local choices = {}
  for _, profile in ipairs(profiles) do
    table.insert(choices, {
      text = "🗑️ " .. profile.name,
      subText = #(profile.apps or {}) .. " apps",
      profileName = profile.filename
    })
  end
  
  local ch = chooser.new(function(choice)
    if not choice then return end
    local path = getProfilePath(choice.profileName)
    os.remove(path)
    alert.show("Deleted: " .. choice.profileName)
  end)
  
  ch:choices(choices)
  ch:placeholderText("Select profile to delete...")
  ch:show()
end

return M
