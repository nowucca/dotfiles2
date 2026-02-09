-- ============================================
-- SPACE LABELS MODULE
-- Core functionality for labeling spaces
-- ============================================

local M = {}

local spaces = require("hs.spaces")
local screen = require("hs.screen")
local window = require("hs.window")
local dialog = require("hs.dialog")
local chooser = require("hs.chooser")
local alert = require("hs.alert")
local data = require("modules.data")

-- Callback for when labels change (set by menubar module)
M.onLabelChanged = nil

-- ============================================
-- CORE FUNCTIONS
-- ============================================

function M.debug()
  local allScreens = screen.allScreens()
  local info = {}
  for _, scr in ipairs(allScreens) do
    local uuid = scr:getUUID()
    local spaceID = spaces.activeSpaces()[uuid]
    table.insert(info, scr:name() .. ": Space " .. tostring(spaceID))
  end
  alert.show(table.concat(info, "\n"))
end

-- Get the spaceID for the focused window's screen
function M.currentKey()
  local win = window.focusedWindow()
  if not win then
    local scr = screen.mainScreen()
    if scr then
      local uuid = scr:getUUID()
      local spaceID = spaces.activeSpaces()[uuid]
      if spaceID then return tostring(spaceID) end
    end
    return nil
  end

  local screenUUID = win:screen():getUUID()
  local spaceID = spaces.activeSpaces()[screenUUID]
  if not spaceID then return nil end

  return tostring(spaceID)
end

-- Get current label
function M.getCurrentLabel()
  local key = M.currentKey()
  if not key then return nil end
  local d = data.load()
  return data.getLabelForSpace(d, key)
end

-- Show current label as alert banner
function M.show()
  local key = M.currentKey()
  if not key then
    alert.show("No active space")
    return
  end

  local d = data.load()
  local label = data.getLabelForSpace(d, key)
  alert.show(label or "No label for this Space")
end

-- Set label for current space
function M.set(text)
  if not text or text == "" then return end

  local key = M.currentKey()
  if not key then return end

  local d = data.load()
  data.setLabelForSpace(d, key, text)
  data.save(d)

  alert.show("Space labeled: " .. text)
  if M.onLabelChanged then M.onLabelChanged() end
end

-- Clear label for current space
function M.clear()
  local key = M.currentKey()
  if not key then return end

  local d = data.load()
  if d.spaces[key] then
    d.spaces[key] = nil
    data.save(d)
    alert.show("Space label cleared")
    if M.onLabelChanged then M.onLabelChanged() end
  end
end

-- Prompt user to enter a label
function M.promptForLabel()
  local currentLabel = M.getCurrentLabel() or ""

  local button, text = dialog.textPrompt(
    "Label This Space",
    "Enter a label for the current workspace:",
    currentLabel,
    "Save",
    "Cancel"
  )

  if button == "Save" and text and text ~= "" then
    M.set(text)
  end
end

-- Show chooser to rebind/apply existing label
function M.rebind()
  local d = data.load()
  local choices = {}

  for labelName, labelData in pairs(d.labels) do
    table.insert(choices, {
      text = labelName,
      subText = "Last used: " .. data.formatDaysAgo(labelData.lastUsed),
      label = labelName
    })
  end

  -- Sort alphabetically
  table.sort(choices, function(a, b)
    return string.lower(a.text) < string.lower(b.text)
  end)

  chooser.new(function(choice)
    if not choice then return end

    local newKey = M.currentKey()
    if not newKey then return end

    local d = data.load()
    data.setLabelForSpace(d, newKey, choice.label)
    data.save(d)

    alert.show("Space labeled: " .. choice.label)
    if M.onLabelChanged then M.onLabelChanged() end
  end):choices(choices):show()
end

-- ============================================
-- LABEL MANAGEMENT
-- ============================================

function M.pruneLabels(daysOld)
  daysOld = daysOld or 30
  local d = data.load()
  local cutoff = os.time() - (daysOld * 86400)
  local pruned = {}

  for labelName, labelData in pairs(d.labels) do
    if (labelData.lastUsed or 0) < cutoff then
      table.insert(pruned, labelName)
    end
  end

  if #pruned == 0 then
    alert.show("No labels older than " .. daysOld .. " days")
    return
  end

  -- Remove pruned labels from spaces and labels
  for _, labelName in ipairs(pruned) do
    d.labels[labelName] = nil
    for spaceId, spaceLabel in pairs(d.spaces) do
      if spaceLabel == labelName then
        d.spaces[spaceId] = nil
      end
    end
  end

  data.save(d)
  alert.show("Pruned " .. #pruned .. " label(s): " .. table.concat(pruned, ", "))
  if M.onLabelChanged then M.onLabelChanged() end
end

function M.deleteLabel(labelName)
  local d = data.load()

  if not d.labels[labelName] then
    alert.show("Label not found: " .. labelName)
    return
  end

  d.labels[labelName] = nil
  for spaceId, spaceLabel in pairs(d.spaces) do
    if spaceLabel == labelName then
      d.spaces[spaceId] = nil
    end
  end

  data.save(d)
  alert.show("Deleted label: " .. labelName)
  if M.onLabelChanged then M.onLabelChanged() end
end

function M.showDeleteLabelChooser()
  local d = data.load()
  local choices = {}

  for labelName, labelData in pairs(d.labels) do
    table.insert(choices, {
      text = "🗑️ " .. labelName,
      subText = "Last used: " .. data.formatDaysAgo(labelData.lastUsed),
      label = labelName
    })
  end

  table.sort(choices, function(a, b)
    return string.lower(a.text) < string.lower(b.text)
  end)

  chooser.new(function(choice)
    if not choice then return end
    M.deleteLabel(choice.label)
  end):choices(choices):placeholderText("Select label to delete"):show()
end

return M
