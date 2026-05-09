-- Agent state tracking. parseTitle is pure. The in-memory state map is
-- keyed by (spaceId, winId, tabId) and refreshed from iTerm snapshots
-- on a timer. State transitions fire M.onChange(prev, next).
local timer = require("hs.timer")
local appWatcher = require("hs.application").watcher
local config = require("core.config")
local log = require("core.log")

local M = {}
M.onChange = nil

local VALID_STATES = { idle = true, run = true, wait = true, done = true, err = true }
local map = {}        -- key -> { state, title, changedAt, spaceId, winId, tabId }
local pollTimer = nil
local watcher = nil
local foreground = true
local itermModule = nil  -- lazy-loaded to avoid circular requires during tests

local function key(spaceId, winId, tabId)
  return tostring(spaceId or "?") .. ":" .. tostring(winId) .. ":" .. tostring(tabId)
end

function M.parseTitle(raw)
  if raw == nil or raw == "" then return { state = "idle", title = "" } end
  local state, rest = raw:match("^%[spaces:(%a+)%]%s*(.*)$")
  if state and VALID_STATES[state] then
    return { state = state, title = rest or "" }
  end
  return { state = "idle", title = raw }
end

function M.get(spaceId, winId, tabId)
  return map[key(spaceId, winId, tabId)]
end

-- Walk every (window, tab) in the map and tally states. Includes idle so the
-- menubar can show a total tab count.
function M.summary()
  local s = { idle = 0, run = 0, wait = 0, done = 0, err = 0 }
  for _, rec in pairs(map) do s[rec.state] = (s[rec.state] or 0) + 1 end
  return s
end

-- Returns all records on a given space, sorted by (winId, tabId).
function M.forSpace(spaceId)
  local out = {}
  for _, rec in pairs(map) do
    if rec.spaceId == spaceId then table.insert(out, rec) end
  end
  table.sort(out, function(a, b)
    if a.winId ~= b.winId then return a.winId < b.winId end
    return a.tabId < b.tabId
  end)
  return out
end

-- Internal: update the map from a snapshot table. Exposed for testing.
function M._refreshFromSnapshot(snap)
  local seen = {}
  for _, w in ipairs(snap.windows or {}) do
    for _, t in ipairs(w.tabs or {}) do
      local k = key(w.space, w.id, t.id)
      seen[k] = true
      local parsed = M.parseTitle(t.title)
      local prev = map[k]
      local rec = {
        spaceId = w.space, winId = w.id, tabId = t.id,
        tabIndex = t.index,
        state = parsed.state, title = parsed.title,
        changedAt = (prev and prev.state == parsed.state) and prev.changedAt or os.time(),
      }
      map[k] = rec
      if M.onChange and (not prev or prev.state ~= parsed.state) then
        log.try(function() M.onChange(prev, rec) end, "agents.onChange")
      end
    end
  end
  -- Prune anything not in the latest snapshot.
  for k in pairs(map) do
    if not seen[k] then map[k] = nil end
  end
end

local function refresh()
  if not itermModule then itermModule = require("core.iterm") end
  local ok, snap = log.try(function() return itermModule.snapshot() end, "agents.refresh snapshot")
  if ok and snap then M._refreshFromSnapshot(snap) end
end

function M.start()
  if pollTimer then return end
  refresh()
  pollTimer = timer.new(config.poll.foregroundSec, refresh)
  pollTimer:start()

  watcher = appWatcher.new(function(name, event)
    if event == appWatcher.activated then
      local fg = (name == "Hammerspoon") or (name == "iTerm2") or (name == "iTerm")
      if fg ~= foreground then
        foreground = fg
        if pollTimer then pollTimer:stop() end
        pollTimer = timer.new(fg and config.poll.foregroundSec or config.poll.backgroundSec, refresh)
        pollTimer:start()
        log.debug("agents: poll cadence " .. (fg and "foreground" or "background"))
      end
    end
  end)
  watcher:start()
end

function M.stop()
  if pollTimer then pollTimer:stop(); pollTimer = nil end
  if watcher then watcher:stop(); watcher = nil end
  map = {}
end

return M
