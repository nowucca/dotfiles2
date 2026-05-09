-- Create and close macOS Spaces. Behaviour-identical port of
-- modules/space-manager.lua, but window-launch loops route through
-- core/iterm.lua and core/chrome.lua instead of inlining their own.
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local timer = require("hs.timer")
local alert = require("hs.alert")
local dialog = require("hs.dialog")
local data = require("core.data")
local log = require("core.log")
local iterm = require("core.iterm")
local chrome = require("core.chrome")
local labels = require("actions.labels")

local M = {}

local function currentSpaceInfo()
  local win = windowMod.focusedWindow()
  local scr = (win and win:screen()) or screenMod.mainScreen()
  if not scr then return nil, nil end
  local uuid = scr:getUUID()
  return spaces.activeSpaces()[uuid], scr
end

local function windowsOnSpace(sid)
  local out = {}
  for _, wid in ipairs(spaces.windowsForSpace(sid) or {}) do
    local w = windowMod.get(wid)
    if w and w:isStandard() then table.insert(out, w) end
  end
  return out
end

-- ============= CLOSE =============

function M.closeCurrentSpace(providedSpaceId, providedScr)
  local sid = providedSpaceId
  local scr = providedScr
  if not sid or not scr then sid, scr = currentSpaceInfo() end
  if not sid or not scr then alert.show("Cannot determine current space"); return end

  local screenSpaces = spaces.spacesForScreen(scr) or {}
  if #screenSpaces <= 1 then alert.show("Only one space on this screen"); return end

  local label = labels.getCurrentLabel() or ("Space " .. tostring(sid))
  local wins = windowsOnSpace(sid)
  log.info("space-manager: closing " .. label .. " (" .. #wins .. " windows)")

  for _, w in ipairs(wins) do log.try(function() w:close() end, "close window") end

  timer.doAfter(0.5, function()
    M._removeSpaceIfEmpty(sid, scr, label, #wins)
  end)
end

function M._removeSpaceIfEmpty(sid, scr, label, originalCount)
  local screenSpaces = spaces.spacesForScreen(scr) or {}
  local target
  for i, s in ipairs(screenSpaces) do
    if s == sid then
      target = (i > 1) and screenSpaces[i - 1] or screenSpaces[i + 1]
      break
    end
  end
  if not target then alert.show("Could not find sibling space"); return end

  log.try(function() spaces.gotoSpace(target) end, "goto sibling")

  timer.doAfter(0.5, function()
    local ok = spaces.removeSpace(sid)
    if ok then
      log.try(function()
        local d = data.load()
        if d.spaces[tostring(sid)] then d.spaces[tostring(sid)] = nil; data.save(d) end
      end, "drop label for closed space")
      alert.show("Closed " .. label .. " · " .. originalCount .. " windows")
    else
      alert.show("Closed windows but could not remove space")
    end
  end)
end

function M.confirmCloseCurrentSpace()
  local sid, scr = currentSpaceInfo()
  if not sid or not scr then alert.show("Cannot determine current space"); return end
  local label = labels.getCurrentLabel() or ("Space " .. tostring(sid))
  local wins = windowsOnSpace(sid)
  local button = dialog.blockAlert("Close " .. label .. "?",
    "This closes " .. #wins .. " window(s) and removes the space.",
    "Close", "Cancel")
  if button == "Close" then M.closeCurrentSpace(sid, scr) end
end

-- ============= CREATE =============

local function newSpaceIdAfterAdd(beforeSet, scr)
  local after = spaces.spacesForScreen(scr) or {}
  for _, sid in ipairs(after) do if not beforeSet[sid] then return sid end end
  return nil
end

function M.createNewSpace()
  local _, scr = currentSpaceInfo()
  scr = scr or screenMod.mainScreen()
  if not scr then alert.show("No screen"); return end

  local button, labelName = dialog.textPrompt("New Space", "Label for the new space:", "", "Create", "Cancel")
  if button ~= "Create" then return end

  local before = {}
  for _, sid in ipairs(spaces.spacesForScreen(scr) or {}) do before[sid] = true end

  if not spaces.addSpaceToScreen(scr, true) then alert.show("Failed to create space"); return end

  timer.doAfter(0.5, function()
    local newSid = newSpaceIdAfterAdd(before, scr)
    if not newSid then alert.show("Created space but could not find it"); return end

    if labelName and labelName ~= "" then
      log.try(function()
        local d = data.load()
        data.setLabelForSpace(d, tostring(newSid), labelName)
        data.save(d)
      end, "set label on new space")
    end

    log.try(function() spaces.gotoSpace(newSid) end, "goto new space")

    timer.doAfter(0.8, function()
      M._populateNewSpace(newSid, scr, labelName)
    end)
  end)
end

-- Default population: an iTerm window plus a Chrome window. Matches the
-- existing space-manager behaviour. Used by the legacy "New Space" hotkey.
-- (The agent launchers in actions/launcher.lua use a different population.)
function M._populateNewSpace(targetSid, targetScreen, labelName)
  iterm.newWindow({ cwd = os.getenv("HOME") })
  timer.doAfter(2.0, function()
    chrome.openWindowOnSpace(targetSid, targetScreen)
    timer.doAfter(2.0, function()
      log.try(function() spaces.gotoSpace(targetSid) end, "final goto")
      alert.show((labelName or "New space") .. " ready")
    end)
  end)
end

return M
