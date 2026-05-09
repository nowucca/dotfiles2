-- Save and restore "space profiles" — a list of apps to launch on a space.
-- Behaviour-identical port of modules/profiles.lua. App launches route
-- through core/iterm.lua and core/chrome.lua. Other apps fall back to
-- hs.application.launchOrFocusByBundleID.
local json = require("hs.json")
local fs = require("hs.fs")
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local application = require("hs.application")
local timer = require("hs.timer")
local alert = require("hs.alert")
local chooser = require("hs.chooser")
local dialog = require("hs.dialog")
local config = require("core.config")
local data = require("core.data")
local log = require("core.log")
local iterm = require("core.iterm")
local chrome = require("core.chrome")
local labels = require("actions.labels")

local M = {}

local function ensureDir() fs.mkdir(config.paths.profiles) end
local function profilePath(name) return config.paths.profiles .. "/" .. name .. ".json" end

local function currentSpaceInfo()
  local win = windowMod.focusedWindow()
  local scr = (win and win:screen()) or screenMod.mainScreen()
  if not scr then return nil, nil end
  return spaces.activeSpaces()[scr:getUUID()], scr
end

local function currentSpaceId()
  local sid = currentSpaceInfo()
  return sid
end

-- Distinct apps with at least one standard window on the current space.
function M.getAppsOnCurrentSpace()
  local sid = currentSpaceId()
  if not sid then return {} end
  local apps, seen = {}, {}
  for _, wid in ipairs(spaces.windowsForSpace(sid) or {}) do
    local win = windowMod.get(wid)
    if win and win:isStandard() then
      local app = win:application()
      if app then
        local name = app:name()
        if name and not seen[name] then
          seen[name] = true
          table.insert(apps, { name = name, bundleID = app:bundleID() })
        end
      end
    end
  end
  return apps
end

function M.saveCurrentSpace(name)
  if not name or name == "" then return end
  ensureDir()
  local profile = {
    name = name,
    label = labels.getCurrentLabel(),
    savedAt = os.time(),
    apps = M.getAppsOnCurrentSpace(),
  }
  local f = io.open(profilePath(name), "w")
  if f then
    f:write(json.encode(profile, true))
    f:close()
    alert.show("Saved " .. name .. " · " .. #profile.apps .. " apps")
  else
    alert.show("Failed to save profile")
  end
end

function M.promptSaveCurrentSpace()
  local current = labels.getCurrentLabel() or ""
  local button, name = dialog.textPrompt("Save Profile", "Profile name:", current, "Save", "Cancel")
  if button == "Save" and name and name ~= "" then M.saveCurrentSpace(name) end
end

function M.listProfiles()
  ensureDir()
  local out = {}
  for file in fs.dir(config.paths.profiles) do
    if file:match("%.json$") then
      local f = io.open(config.paths.profiles .. "/" .. file, "r")
      if f then
        local content = f:read("*a")
        f:close()
        local p = json.decode(content)
        if p then p.filename = file:gsub("%.json$", ""); table.insert(out, p) end
      end
    end
  end
  table.sort(out, function(a, b) return string.lower(a.name or "") < string.lower(b.name or "") end)
  return out
end

local function launchApp(appInfo, targetSid, targetScreen)
  local name = appInfo.name
  if name == "iTerm2" or name == "iTerm" then
    iterm.newWindow({})
    return
  end
  if name == "Google Chrome" then
    chrome.openWindowOnSpace(targetSid, targetScreen)
    return
  end
  -- Generic app: launch and let macOS place; explicit space placement is
  -- best-effort because most apps don't have AppleScript surfaces.
  if appInfo.bundleID then
    application.launchOrFocusByBundleID(appInfo.bundleID)
  else
    application.launchOrFocus(name)
  end
end

function M.restoreProfile(name)
  local f = io.open(profilePath(name), "r")
  if not f then alert.show("Profile not found"); return end
  local content = f:read("*a")
  f:close()
  local profile = json.decode(content)
  if not profile then alert.show("Invalid profile"); return end

  local targetSid, targetScreen = currentSpaceInfo()
  if not targetSid or not targetScreen then alert.show("Cannot determine current space"); return end

  if profile.label then labels.set(profile.label) end
  alert.show("Restoring " .. profile.name .. " · " .. #(profile.apps or {}) .. " apps")

  for i, app in ipairs(profile.apps or {}) do
    timer.doAfter(i * 2.5, function()
      log.try(function() launchApp(app, targetSid, targetScreen) end, "restore launch " .. (app.name or "?"))
    end)
  end
end

function M.showRestoreChooser()
  local list = M.listProfiles()
  if #list == 0 then alert.show("No saved profiles"); return end
  local choices = {}
  for _, p in ipairs(list) do
    table.insert(choices, {
      text = p.name,
      subText = #(p.apps or {}) .. " apps · " ..
                (p.label and ("Label: " .. p.label) or "No label") ..
                " · Saved " .. data.formatDaysAgo(p.savedAt),
      profileName = p.filename,
    })
  end
  chooser.new(function(choice) if choice then M.restoreProfile(choice.profileName) end end)
    :choices(choices):placeholderText("Select profile to restore..."):show()
end

function M.showDeleteChooser()
  local list = M.listProfiles()
  if #list == 0 then alert.show("No saved profiles"); return end
  local choices = {}
  for _, p in ipairs(list) do
    table.insert(choices, { text = p.name, subText = #(p.apps or {}) .. " apps", profileName = p.filename })
  end
  chooser.new(function(choice)
    if not choice then return end
    os.remove(profilePath(choice.profileName))
    alert.show("Deleted " .. choice.profileName)
  end):choices(choices):placeholderText("Select profile to delete..."):show()
end

return M
