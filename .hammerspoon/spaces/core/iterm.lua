-- Single point of contact for iTerm. All AppleScript lives here so the rest
-- of the product reasons in Lua. Creation/focus methods are added in Task 7.
local osascript = hs.osascript
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local log = require("core.log")
local timer = require("hs.timer")

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

-- Escape a string for embedding in an AppleScript string literal.
local function asEscape(s)
  if not s then return "" end
  return s:gsub("\\", "\\\\"):gsub('"', '\\"')
end

-- Create a new iTerm window. Returns the new window id (integer) or nil.
-- opts: { profile, cwd, command, title }
function M.newWindow(opts)
  opts = opts or {}
  local profile = opts.profile or "Default"
  local cwd = opts.cwd
  local command = opts.command
  local title = opts.title

  local script = string.format([[
    tell application "iTerm2"
      set newWin to (create window with profile "%s")
      tell current session of newWin
%s%s%s
      end tell
      return id of newWin
    end tell
  ]],
    asEscape(profile),
    cwd and ('        write text "cd ' .. asEscape(cwd) .. '"\n') or "",
    command and ('        write text "' .. asEscape(command) .. '"\n') or "",
    title and ('        set name to "' .. asEscape(title) .. '"\n') or ""
  )

  local ok, result, _ = osascript.applescript(script)
  if not ok then
    log.warn("iterm.newWindow: AppleScript failed")
    return nil
  end
  return tonumber(result)
end

-- Create a new tab in a specific window. Returns the new tab's session UUID
-- (string), matching the snapshot's `id` field shape, or nil on failure.
function M.newTab(winId, opts)
  if not winId then return nil end
  opts = opts or {}
  local cwd = opts.cwd
  local command = opts.command
  local title = opts.title

  local script = string.format([[
    tell application "iTerm2"
      tell window id %d
        set newTab to (create tab with default profile)
        set newSession to current session of newTab
        tell newSession
%s%s%s
        end tell
        return unique ID of newSession
      end tell
    end tell
  ]],
    winId,
    cwd and ('          write text "cd ' .. asEscape(cwd) .. '"\n') or "",
    command and ('          write text "' .. asEscape(command) .. '"\n') or "",
    title and ('          set name to "' .. asEscape(title) .. '"\n') or ""
  )

  local ok, result, _ = osascript.applescript(script)
  if not ok then
    log.warn("iterm.newTab: AppleScript failed for window " .. tostring(winId))
    return nil
  end
  return result  -- session UUID string
end

-- Set a tab's session name (the visible "title"). Used to apply the
-- [spaces:idle] prefix on launch so the tab shows up in the menubar before
-- the agent starts overwriting it.
function M.setTabTitle(winId, tabIndex, text)
  local script = string.format([[
    tell application "iTerm2"
      tell window id %d
        tell tab %d
          tell current session
            set name to "%s"
          end tell
        end tell
      end tell
    end tell
  ]], winId, tabIndex, asEscape(text))
  osascript.applescript(script)
end

-- Switch to the window's space (if needed), then select and focus the given
-- tab by 1-based index. This is the primitive the menubar uses for
-- click-to-focus rows.
function M.focusTab(winId, tabIndex)
  -- 1. Find the window's space and switch to it if we're not there.
  local snap = M.snapshot()
  local target
  for _, w in ipairs(snap.windows) do if w.id == winId then target = w break end end
  if target and target.space then
    spaces.gotoSpace(target.space)
  end

  -- 2. Activate iTerm and select the tab. Wait briefly for the space switch.
  timer.doAfter(0.3, function()
    local script = string.format([[
      tell application "iTerm2"
        activate
        tell window id %d
          select
          tell tab %d
            select
          end tell
        end tell
      end tell
    ]], winId, tabIndex)
    osascript.applescript(script)
  end)
end

return M
