-- ============================================
-- DATA PERSISTENCE MODULE
-- Handles loading/saving workspace labels
-- ============================================

local M = {}

local json = require("hs.json")
local fs = require("hs.fs")

-- Data structure:
-- {
--   "labels": { "LabelName": { "lastUsed": timestamp }, ... },
--   "spaces": { "spaceId": "LabelName", ... }
-- }

local dataPath = hs.configdir .. "/workspace-notes.json"

function M.load()
  if fs.attributes(dataPath) then
    local f = io.open(dataPath)
    if f then
      local content = f:read("*a")
      f:close()
      local data = json.decode(content)
      if data then
        -- Migrate old format if needed
        if not data.labels then
          local oldNotes = data
          data = { labels = {}, spaces = {} }
          for spaceId, labelName in pairs(oldNotes) do
            if type(labelName) == "string" then
              data.spaces[spaceId] = labelName
              if not data.labels[labelName] then
                data.labels[labelName] = { lastUsed = os.time() }
              end
            end
          end
        end
        return data
      end
    end
  end
  return { labels = {}, spaces = {} }
end

function M.save(data)
  local f = io.open(dataPath, "w")
  if f then
    f:write(json.encode(data, true))
    f:close()
  end
end

-- Helper to get label for a space
function M.getLabelForSpace(data, spaceId)
  return data.spaces[spaceId]
end

-- Helper to set label for a space (updates lastUsed)
function M.setLabelForSpace(data, spaceId, labelName)
  data.spaces[spaceId] = labelName
  if not data.labels[labelName] then
    data.labels[labelName] = {}
  end
  data.labels[labelName].lastUsed = os.time()
end

-- Get all labels sorted alphabetically with metadata
function M.getAllLabels()
  local data = M.load()
  local sortedLabels = {}
  
  for labelName, labelData in pairs(data.labels) do
    table.insert(sortedLabels, {
      name = labelName,
      lastUsed = labelData.lastUsed or 0
    })
  end
  
  table.sort(sortedLabels, function(a, b)
    return string.lower(a.name) < string.lower(b.name)
  end)
  
  return sortedLabels
end

-- Format "days ago" string
function M.formatDaysAgo(timestamp)
  local daysAgo = math.floor((os.time() - (timestamp or 0)) / 86400)
  if daysAgo == 0 then
    return "today"
  elseif daysAgo == 1 then
    return "yesterday"
  else
    return daysAgo .. " days ago"
  end
end

return M
