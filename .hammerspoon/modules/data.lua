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

-- Validate and clean the data structure to prevent corruption
local function validateAndClean(data)
  if not data then return { labels = {}, spaces = {} } end
  
  local cleanLabels = {}
  local cleanSpaces = {}
  
  -- Clean labels: only keep entries that have proper { lastUsed: number } structure
  if data.labels then
    for key, value in pairs(data.labels) do
      if type(value) == "table" and type(value.lastUsed) == "number" then
        cleanLabels[key] = value
      elseif type(value) == "string" and tonumber(key) then
        -- This is a space->label mapping that got put in wrong section
        cleanSpaces[key] = value
      end
    end
  end
  
  -- Clean spaces: only keep entries that are spaceId -> labelName (string)
  if data.spaces then
    for key, value in pairs(data.spaces) do
      if type(value) == "string" then
        cleanSpaces[key] = value
        -- Ensure the label exists in labels section
        if not cleanLabels[value] then
          cleanLabels[value] = { lastUsed = os.time() }
        end
      end
      -- Skip entries where value is a table (those are misplaced label entries)
    end
  end
  
  return { labels = cleanLabels, spaces = cleanSpaces }
end

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
        -- Always validate and clean the data
        return validateAndClean(data)
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
