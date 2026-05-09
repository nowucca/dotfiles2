-- Chooser-based switcher for the spaces on the current screen.
-- Behaviour-identical port of the existing modules/space-switcher.lua.
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local chooserMod = require("hs.chooser")
local timer = require("hs.timer")
local data = require("core.data")

local M = {}
M.onSpaceChanged = nil

function M.getSpacesForCurrentScreen()
  local win = windowMod.focusedWindow()
  local scr = (win and win:screen()) or screenMod.mainScreen()
  if not scr then return {} end

  local uuid = scr:getUUID()
  local all = spaces.spacesForScreen(uuid) or {}
  local active = spaces.activeSpaces()[uuid]
  local d = data.load()
  local result = {}
  for i, sid in ipairs(all) do
    table.insert(result, {
      spaceId = sid,
      index = i,
      label = data.getLabelForSpace(d, tostring(sid)),
      isActive = (sid == active),
      screenUUID = uuid,
    })
  end
  return result
end

function M.gotoSpace(spaceId)
  if not spaceId then return end
  spaces.gotoSpace(spaceId)
  timer.doAfter(0.3, function()
    if M.onSpaceChanged then M.onSpaceChanged() end
  end)
end

function M.show()
  local list = M.getSpacesForCurrentScreen()
  local choices = {}
  for _, info in ipairs(list) do
    local prefix = info.isActive and "→ " or "   "
    local text = info.label and (prefix .. info.label) or (prefix .. "Space " .. info.index)
    table.insert(choices, {
      text = text,
      subText = "Space ID: " .. info.spaceId .. (info.isActive and " (current)" or ""),
      spaceId = info.spaceId,
    })
  end
  chooserMod.new(function(choice)
    if not choice then return end
    M.gotoSpace(choice.spaceId)
  end):choices(choices):placeholderText("Switch to space..."):searchSubText(true):show()
end

return M
