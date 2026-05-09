-- Chrome window placement on a target space. Mirrors the existing
-- modules/app-launcher.lua Chrome path: AppleScript "make new window",
-- then a multi-attempt locate-and-move loop with a Stage Manager workaround
-- (focused window may not show up in app:allWindows()).
local osascript = hs.osascript
local application = require("hs.application")
local windowMod = require("hs.window")
local spaces = require("hs.spaces")
local timer = require("hs.timer")
local alert = require("hs.alert")
local log = require("core.log")

local M = {}

local function existingWindowIds(app)
  local ids = {}
  if app then
    for _, win in ipairs(app:allWindows()) do ids[win:id()] = true end
  end
  return ids
end

local function moveWindowToTarget(win, winId, targetSpaceId, targetScreen)
  local windowSpaces = spaces.windowSpaces(winId) or {}
  local currentSpace = windowSpaces[1]
  local windowScreen = win:screen()
  local targetScreenUUID = targetScreen:getUUID()

  local onCorrectSpace = currentSpace == targetSpaceId
  local onCorrectScreen = windowScreen and windowScreen:getUUID() == targetScreenUUID

  if onCorrectSpace and onCorrectScreen then
    log.debug("chrome: window already on correct space/screen")
    log.try(function() win:focus(); win:raise() end, "chrome focus")
    return
  end

  if not onCorrectScreen then
    log.try(function() win:setFrame(targetScreen:frame()) end, "chrome setFrame")
  end

  timer.doAfter(0.3, function()
    log.try(function() spaces.gotoSpace(targetSpaceId) end, "chrome gotoSpace")
    timer.doAfter(0.5, function()
      log.try(function() spaces.moveWindowToSpace(winId, targetSpaceId) end, "chrome moveWindowToSpace")
      timer.doAfter(0.3, function()
        local newSpaces = spaces.windowSpaces(winId) or {}
        if newSpaces[1] ~= targetSpaceId then
          -- Stage Manager workaround: nudge the frame and try again.
          log.try(function()
            local fw = windowMod.get(winId)
            if fw then
              local frame = targetScreen:frame()
              frame.x = frame.x + 50; frame.y = frame.y + 50
              fw:setFrame(frame)
            end
          end, "chrome setFrame nudge")
          timer.doAfter(0.3, function()
            log.try(function() spaces.moveWindowToSpace(winId, targetSpaceId) end, "chrome retry move")
          end)
        end
        timer.doAfter(0.2, function()
          log.try(function()
            local fw = windowMod.get(winId)
            if fw then fw:focus(); fw:raise() end
          end, "chrome final focus")
        end)
      end)
    end)
  end)
end

-- Open a new Chrome window on the given space/screen. The Stage Manager
-- workaround tries focusedWindow() before falling back to allWindows().
function M.openWindowOnSpace(targetSpaceId, targetScreen)
  if not targetSpaceId or not targetScreen then
    alert.show("Cannot determine current space")
    return
  end

  local chrome = application.get("Google Chrome")
  local before = existingWindowIds(chrome)

  log.info("chrome: opening on space " .. tostring(targetSpaceId))
  spaces.gotoSpace(targetSpaceId)

  timer.doAfter(0.5, function()
    chrome = application.get("Google Chrome")
    before = existingWindowIds(chrome)

    if chrome then
      osascript.applescript([[tell application "Google Chrome" to make new window]])
    else
      application.launchOrFocus("Google Chrome")
    end

    local attempts = 0
    local maxAttempts = 40
    local function checkAndMove()
      attempts = attempts + 1
      local app = application.get("Google Chrome")

      if app and attempts == 1 then
        local focused = windowMod.focusedWindow()
        if focused and focused:application() and focused:application():name() == "Google Chrome" then
          if not before[focused:id()] and focused:isStandard() then
            moveWindowToTarget(focused, focused:id(), targetSpaceId, targetScreen)
            return
          end
        end
      end

      if app then
        for _, win in ipairs(app:allWindows()) do
          if not before[win:id()] and win:isStandard() then
            moveWindowToTarget(win, win:id(), targetSpaceId, targetScreen)
            return
          end
        end
      end

      if attempts < maxAttempts then
        timer.doAfter(0.1, checkAndMove)
      else
        log.warn("chrome: could not detect new window after " .. maxAttempts .. " attempts (Stage Manager may hide it)")
        spaces.gotoSpace(targetSpaceId)
      end
    end
    timer.doAfter(chrome and 1.0 or 2.0, checkAndMove)
  end)
end

return M
