-- ============================================
-- SPACE SWITCHER MODULE
-- Switch between spaces using chooser UI
-- ============================================

local M = {}

local spaces = require("hs.spaces")
local screen = require("hs.screen")
local window = require("hs.window")
local chooser = require("hs.chooser")
local timer = require("hs.timer")
local data = require("modules.data")

-- Callback for when space changes (set by menubar module)
M.onSpaceChanged = nil

-- Get all spaces on the current screen with their labels
function M.getSpacesForCurrentScreen()
  local win = window.focusedWindow()
  local scr = win and win:screen() or screen.mainScreen()
  if not scr then return {} end

  local screenUUID = scr:getUUID()
  local allSpaces = spaces.spacesForScreen(screenUUID) or {}
  local activeSpaceId = spaces.activeSpaces()[screenUUID]
  local d = data.load()
  local result = {}

  for i, spaceId in ipairs(allSpaces) do
    local label = data.getLabelForSpace(d, tostring(spaceId))
    local isActive = (spaceId == activeSpaceId)
    table.insert(result, {
      spaceId = spaceId,
      index = i,
      label = label,
      isActive = isActive,
      screenUUID = screenUUID
    })
  end

  return result
end

-- Switch to a specific space
function M.gotoSpace(spaceId)
  if not spaceId then return end
  spaces.gotoSpace(spaceId)
  -- Update after a short delay for space change to complete
  timer.doAfter(0.3, function()
    if M.onSpaceChanged then M.onSpaceChanged() end
  end)
end

-- Show space switcher chooser
function M.show()
  local spaceList = M.getSpacesForCurrentScreen()
  local choices = {}

  for _, spaceInfo in ipairs(spaceList) do
    local text = ""
    local prefix = spaceInfo.isActive and "→ " or "   "

    if spaceInfo.label then
      text = prefix .. spaceInfo.label
    else
      text = prefix .. "Space " .. spaceInfo.index
    end

    table.insert(choices, {
      text = text,
      subText = "Space ID: " .. spaceInfo.spaceId .. (spaceInfo.isActive and " (current)" or ""),
      spaceId = spaceInfo.spaceId,
      index = spaceInfo.index
    })
  end

  local ch = chooser.new(function(choice)
    if not choice then return end
    M.gotoSpace(choice.spaceId)
  end)

  ch:choices(choices)
  ch:placeholderText("Switch to space...")
  ch:searchSubText(true)
  ch:show()
end

return M
