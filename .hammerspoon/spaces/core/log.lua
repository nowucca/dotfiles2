-- Leveled logging used product-wide. Replaces ad-hoc print() calls.
-- log.try() wraps pcall and logs the error with a context string on failure.
local config = require("core.config")

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }

local M = {}
local currentLevel = LEVELS[config.log.level] or LEVELS.info
local writer = function(line) print(line) end

function M.setLevel(name)
  currentLevel = LEVELS[name] or currentLevel
end

function M._setWriter(fn)
  writer = fn
end

local function emit(levelName, msg)
  if LEVELS[levelName] < currentLevel then return end
  local ts = os.date("%H:%M:%S")
  writer(string.format("[%s] %-5s %s", ts, levelName:upper(), msg))
end

function M.debug(msg) emit("debug", msg) end
function M.info(msg)  emit("info", msg) end
function M.warn(msg)  emit("warn", msg) end
function M.error(msg) emit("error", msg) end

-- pcall wrapper. Returns (ok, result). On failure logs at error level with
-- the supplied context so the failure point is identifiable.
function M.try(fn, ctx)
  local ok, result = pcall(fn)
  if not ok then
    M.error((ctx or "log.try") .. ": " .. tostring(result))
  end
  return ok, result
end

return M
