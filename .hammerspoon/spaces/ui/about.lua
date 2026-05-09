-- About dialog. Shows version, paths, label/profile counts, agent summary.
-- Single OK button.
local dialog = require("hs.dialog")
local config = require("core.config")
local data = require("core.data")
local agents = require("core.agents")

local M = {}

local function countLabels()
  local d = data.load()
  local n = 0
  for _ in pairs(d.labels) do n = n + 1 end
  return n
end

local function countProfiles()
  local fs = require("hs.fs")
  local n = 0
  if fs.attributes(config.paths.profiles) then
    for file in fs.dir(config.paths.profiles) do
      if file:match("%.json$") then n = n + 1 end
    end
  end
  return n
end

function M.show()
  local s = agents.summary()
  local body = string.format(
    "%s %s\n\nConfig: %s\nData:   %s\nProfiles: %s (%d saved)\n\n%d labels tracked\nAgents: run %d  wait %d  done %d  err %d  idle %d",
    config.brand.name, config.brand.version,
    hs.configdir .. "/spaces",
    config.paths.data,
    config.paths.profiles, countProfiles(),
    countLabels(),
    s.run, s.wait, s.done, s.err, s.idle
  )
  dialog.alert(0, 0, function() end, "About " .. config.brand.name, body, "OK")
end

return M
