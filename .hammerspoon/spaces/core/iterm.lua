-- Single point of contact for iTerm. All AppleScript lives here so the rest
-- of the product reasons in Lua. Creation/focus methods are added in Task 7.
local osascript = hs.osascript
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local log = require("core.log")

local M = {}

-- Returns { windows = { { id, screen, space, tabs = { {id, title, isProcessing}, ... } } } }
-- Window id is iTerm's window id (integer). Screen is a hs.screen object or
-- nil. Space is the hs.spaces space ID for the screen the window is on, or
-- nil if the window's space can't be resolved.
function M.snapshot()
  local script = [[
    tell application "iTerm2"
      set output to ""
      repeat with w in windows
        try
          set wid to id of w
          set output to output & "W:" & wid & "\n"
          set tabcount to count of tabs of w
          repeat with i from 1 to tabcount
            try
              set t to tab i of w
              set s to current session of t
              set suid to unique ID of s
              set sname to ""
              try
                set sname to name of s
              end try
              set sprocessing to is processing of s
              set output to output & "T:" & i & "|" & suid & "|" & sprocessing & "|" & sname & "\n"
            end try
          end repeat
        end try
      end repeat
      return output
    end tell
  ]]

  local ok, raw, _ = osascript.applescript(script)
  if not ok then
    log.warn("iterm.snapshot: AppleScript failed")
    return { windows = {} }
  end

  local windows = {}
  local current
  for line in (raw or ""):gmatch("[^\n]+") do
    local kind, body = line:match("^(%a):(.+)$")
    if kind == "W" then
      local wid = tonumber(body)
      current = { id = wid, tabs = {} }
      table.insert(windows, current)
    elseif kind == "T" and current then
      -- Format: index|uuid|processing|name
      local idx, uid, processing, title = body:match("^(%d+)|([^|]+)|(%a+)|(.*)$")
      if idx then
        table.insert(current.tabs, {
          id = uid,
          index = tonumber(idx),
          isProcessing = (processing == "true"),
          title = title or "",
        })
      end
    end
  end

  -- Resolve hs.screen and space ID for each window. Note: hs.window.get(id)
  -- only returns a window object for windows Hammerspoon currently tracks
  -- (Stage Manager + inactive-space windows are often hidden from it). But
  -- hs.spaces.windowSpaces accepts the raw window ID and works regardless,
  -- so we ask it directly for the space attribution.
  for _, w in ipairs(windows) do
    local sps = spaces.windowSpaces(w.id) or {}
    w.space = sps[1]
    local hsWin = windowMod.get(w.id)
    if hsWin then w.screen = hsWin:screen() end
  end

  return { windows = windows }
end

return M
