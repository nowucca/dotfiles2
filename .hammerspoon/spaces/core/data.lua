-- JSON-backed persistence for label data and agent cwd recents.
-- Schema:
--   {
--     labels   = { LabelName = { lastUsed = ts }, ... },
--     spaces   = { spaceId   = "LabelName", ... },
--     agentCwds = { "/path/a", "/path/b", ... }   -- LRU, max 10
--   }
local json = require("hs.json")
local fs = require("hs.fs")
local config = require("core.config")

local M = {}
local CWD_CAP = 10

local function validateAndClean(d)
  if not d then return { labels = {}, spaces = {}, agentCwds = {} } end

  local cleanLabels = {}
  local cleanSpaces = {}
  local cleanCwds = {}

  if d.labels then
    for key, value in pairs(d.labels) do
      if type(value) == "table" and type(value.lastUsed) == "number" then
        cleanLabels[key] = value
      elseif type(value) == "string" and tonumber(key) then
        -- Misplaced space->label mapping. Lift it into spaces.
        cleanSpaces[key] = value
      end
    end
  end

  if d.spaces then
    for key, value in pairs(d.spaces) do
      if type(value) == "string" then
        cleanSpaces[key] = value
        if not cleanLabels[value] then
          cleanLabels[value] = { lastUsed = os.time() }
        end
      end
    end
  end

  if d.agentCwds and type(d.agentCwds) == "table" then
    for _, p in ipairs(d.agentCwds) do
      if type(p) == "string" then table.insert(cleanCwds, p) end
    end
  end

  return { labels = cleanLabels, spaces = cleanSpaces, agentCwds = cleanCwds }
end

M._validateAndClean = validateAndClean  -- exposed for tests

function M.load()
  if not fs.attributes(config.paths.data) then
    return { labels = {}, spaces = {}, agentCwds = {} }
  end

  local f = io.open(config.paths.data, "r")
  if not f then return { labels = {}, spaces = {}, agentCwds = {} } end
  local content = f:read("*a")
  f:close()

  local d = json.decode(content)
  if not d then return { labels = {}, spaces = {}, agentCwds = {} } end

  -- Migrate pre-labels format if needed.
  if not d.labels and not d.spaces then
    local old = d
    d = { labels = {}, spaces = {}, agentCwds = {} }
    for spaceId, labelName in pairs(old) do
      if type(labelName) == "string" then
        d.spaces[spaceId] = labelName
        d.labels[labelName] = { lastUsed = os.time() }
      end
    end
  end

  return validateAndClean(d)
end

function M.save(d)
  local f = io.open(config.paths.data, "w")
  if f then
    f:write(json.encode(d, true))
    f:close()
  end
end

function M.getLabelForSpace(d, spaceId)
  return d.spaces[spaceId]
end

function M.setLabelForSpace(d, spaceId, labelName)
  d.spaces[spaceId] = labelName
  if not d.labels[labelName] then d.labels[labelName] = {} end
  d.labels[labelName].lastUsed = os.time()
end

function M.getAllLabels()
  local d = M.load()
  local sorted = {}
  for name, meta in pairs(d.labels) do
    table.insert(sorted, { name = name, lastUsed = meta.lastUsed or 0 })
  end
  table.sort(sorted, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
  return sorted
end

function M.formatDaysAgo(timestamp)
  local days = math.floor((os.time() - (timestamp or 0)) / 86400)
  if days <= 0 then return "today" end
  if days == 1 then return "yesterday" end
  return days .. " days ago"
end

-- Move-to-front add for the agent cwd recents list, capped at CWD_CAP entries.
function M.pushAgentCwd(d, path)
  if not path or path == "" then return end
  d.agentCwds = d.agentCwds or {}
  local out = { path }
  for _, p in ipairs(d.agentCwds) do
    if p ~= path and #out < CWD_CAP then table.insert(out, p) end
  end
  d.agentCwds = out
end

return M
