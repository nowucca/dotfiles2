require("hs.ipc")

-- Pre-load required modules (fixes lazy loading issues)
local menubar = require("hs.menubar")
local spaces = require("hs.spaces")
local json = require("hs.json")
local screen = require("hs.screen")
local window = require("hs.window")
local dialog = require("hs.dialog")
local chooser = require("hs.chooser")
local timer = require("hs.timer")
local fs = require("hs.fs")
local alert = require("hs.alert")

ws = {}
ws.menubar = nil

-- ============================================
-- DATA PERSISTENCE
-- Data structure:
-- {
--   "labels": { "LabelName": { "lastUsed": timestamp }, ... },
--   "spaces": { "spaceId": "LabelName", ... }
-- }
-- ============================================

local dataPath = hs.configdir .. "/workspace-notes.json"

local function loadData()
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

local function saveData(data)
  local f = io.open(dataPath, "w")
  if f then
    f:write(json.encode(data, true))
    f:close()
  end
end

-- Helper to get label for a space
local function getLabelForSpace(data, spaceId)
  return data.spaces[spaceId]
end

-- Helper to set label for a space (updates lastUsed)
local function setLabelForSpace(data, spaceId, labelName)
  data.spaces[spaceId] = labelName
  if not data.labels[labelName] then
    data.labels[labelName] = {}
  end
  data.labels[labelName].lastUsed = os.time()
end

-- ============================================
-- CORE FUNCTIONS
-- ============================================

function ws.debug()
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
function ws.currentKey()
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

function ws.show()
  local key = ws.currentKey()
  if not key then
    alert.show("No active space")
    return
  end

  local data = loadData()
  local label = getLabelForSpace(data, key)
  alert.show(label or "No label for this Space")
end

function ws.set(text)
  if not text or text == "" then return end

  local key = ws.currentKey()
  if not key then return end

  local data = loadData()
  setLabelForSpace(data, key, text)
  saveData(data)

  alert.show("Space labeled: " .. text)
  ws.updateMenubar()
end

function ws.rebind()
  local data = loadData()
  local choices = {}

  for labelName, labelData in pairs(data.labels) do
    local daysAgo = math.floor((os.time() - (labelData.lastUsed or 0)) / 86400)
    local subText = "Last used: "
    if daysAgo == 0 then
      subText = subText .. "today"
    elseif daysAgo == 1 then
      subText = subText .. "yesterday"
    else
      subText = subText .. daysAgo .. " days ago"
    end

    table.insert(choices, {
      text = labelName,
      subText = subText,
      label = labelName
    })
  end

  -- Sort alphabetically
  table.sort(choices, function(a, b)
    return string.lower(a.text) < string.lower(b.text)
  end)

  chooser.new(function(choice)
    if not choice then return end

    local newKey = ws.currentKey()
    if not newKey then return end

    local data = loadData()
    setLabelForSpace(data, newKey, choice.label)
    saveData(data)

    alert.show("Space labeled: " .. choice.label)
    ws.updateMenubar()
  end):choices(choices):show()
end

-- ============================================
-- LABEL MANAGEMENT
-- ============================================

function ws.pruneLabels(daysOld)
  daysOld = daysOld or 30
  local data = loadData()
  local cutoff = os.time() - (daysOld * 86400)
  local pruned = {}

  for labelName, labelData in pairs(data.labels) do
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
    data.labels[labelName] = nil
    -- Also remove from spaces that use this label
    for spaceId, spaceLabel in pairs(data.spaces) do
      if spaceLabel == labelName then
        data.spaces[spaceId] = nil
      end
    end
  end

  saveData(data)
  alert.show("Pruned " .. #pruned .. " label(s): " .. table.concat(pruned, ", "))
  ws.updateMenubar()
end

function ws.deleteLabel(labelName)
  local data = loadData()

  if not data.labels[labelName] then
    alert.show("Label not found: " .. labelName)
    return
  end

  data.labels[labelName] = nil
  -- Also remove from spaces that use this label
  for spaceId, spaceLabel in pairs(data.spaces) do
    if spaceLabel == labelName then
      data.spaces[spaceId] = nil
    end
  end

  saveData(data)
  alert.show("Deleted label: " .. labelName)
  ws.updateMenubar()
end

function ws.showDeleteLabelChooser()
  local data = loadData()
  local choices = {}

  for labelName, labelData in pairs(data.labels) do
    local daysAgo = math.floor((os.time() - (labelData.lastUsed or 0)) / 86400)
    local subText = "Last used: "
    if daysAgo == 0 then
      subText = subText .. "today"
    elseif daysAgo == 1 then
      subText = subText .. "yesterday"
    else
      subText = subText .. daysAgo .. " days ago"
    end

    table.insert(choices, {
      text = "🗑️ " .. labelName,
      subText = subText,
      label = labelName
    })
  end

  -- Sort alphabetically
  table.sort(choices, function(a, b)
    return string.lower(a.text) < string.lower(b.text)
  end)

  chooser.new(function(choice)
    if not choice then return end
    ws.deleteLabel(choice.label)
  end):choices(choices):placeholderText("Select label to delete"):show()
end

-- ============================================
-- MENUBAR WIDGET
-- ============================================

function ws.getCurrentLabel()
  local key = ws.currentKey()
  if not key then return nil end
  local data = loadData()
  return getLabelForSpace(data, key)
end

function ws.promptForLabel()
  local currentLabel = ws.getCurrentLabel() or ""

  local button, text = dialog.textPrompt(
    "Label This Space",
    "Enter a label for the current workspace:",
    currentLabel,
    "Save",
    "Cancel"
  )

  if button == "Save" and text and text ~= "" then
    ws.set(text)
  end
end

function ws.clearLabel()
  local key = ws.currentKey()
  if not key then return end

  local data = loadData()
  if data.spaces[key] then
    data.spaces[key] = nil
    saveData(data)
    alert.show("Space label cleared")
    ws.updateMenubar()
  end
end

function ws.updateMenubar()
  if not ws.menubar then return end

  local label = ws.getCurrentLabel()
  if label then
    ws.menubar:setTitle("🏷️ " .. label)
  else
    ws.menubar:setTitle("🏷️")
  end
end

function ws.buildMenu()
  local menu = {}
  local data = loadData()
  local key = ws.currentKey()
  local currentLabel = key and getLabelForSpace(data, key) or nil

  -- Current info
  if currentLabel then
    table.insert(menu, { title = "Current: " .. currentLabel, disabled = true })
  else
    table.insert(menu, { title = "Current: (unlabeled)", disabled = true })
  end
  table.insert(menu, { title = "-" })

  -- Actions
  table.insert(menu, {
    title = "Set Label...",
    fn = function() ws.promptForLabel() end
  })

  if currentLabel then
    table.insert(menu, {
      title = "Clear Label",
      fn = function() ws.clearLabel() end
    })
  end

  -- Collect all labels, sorted alphabetically
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

  if #sortedLabels > 0 then
    table.insert(menu, { title = "-" })
    table.insert(menu, { title = "Apply Label (" .. #sortedLabels .. " total):", disabled = true })

    for _, labelInfo in ipairs(sortedLabels) do
      local labelName = labelInfo.name
      local isCurrent = (labelName == currentLabel)
      local daysAgo = math.floor((os.time() - labelInfo.lastUsed) / 86400)
      local ageHint = ""
      if daysAgo > 7 then
        ageHint = " (" .. daysAgo .. "d)"
      end

      table.insert(menu, {
        title = (isCurrent and "→ " or "   ") .. labelName .. ageHint,
        fn = function()
          local newKey = ws.currentKey()
          if newKey then
            local data = loadData()
            setLabelForSpace(data, newKey, labelName)
            saveData(data)
            alert.show("Space labeled: " .. labelName)
            ws.updateMenubar()
          end
        end
      })
    end
  end

  -- Management section
  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Delete a Label...",
    fn = function() ws.showDeleteLabelChooser() end
  })
  table.insert(menu, {
    title = "Prune Labels",
    menu = {
      {
        title = "Older than 7 days",
        fn = function() ws.pruneLabels(7) end
      },
      {
        title = "Older than 30 days",
        fn = function() ws.pruneLabels(30) end
      },
      {
        title = "Older than 90 days",
        fn = function() ws.pruneLabels(90) end
      }
    }
  })

  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Show Banner",
    fn = function() ws.show() end
  })
  table.insert(menu, {
    title = "Debug Info",
    fn = function() ws.debug() end
  })

  return menu
end

function ws.initMenubar()
  if ws.menubar then
    ws.menubar:delete()
    ws.menubar = nil
  end

  -- Create menubar with autosave name for position persistence
  ws.menubar = menubar.new(true, "SpaceLabels")
  if ws.menubar then
    -- Higher priority = further right in menubar (closer to Control Center)
    -- System items are around 1000+, setting higher pushes it right
    ws.menubar:priority(9999)
    ws.menubar:setMenu(ws.buildMenu)
    ws.updateMenubar()
    print("Menubar created with priority 9999 (right position)")
  else
    print("ERROR: menubar.new() returned nil")
  end
end

-- ============================================
-- WATCHERS
-- ============================================

ws.spaceWatcher = spaces.watcher.new(function()
  ws.updateMenubar()
end)

ws.screenWatcher = screen.watcher.new(function()
  timer.doAfter(0.5, function()
    ws.updateMenubar()
  end)
end)

-- ============================================
-- INITIALIZATION
-- ============================================

print("Space Labels script loading...")
ws.initMenubar()
ws.spaceWatcher:start()
ws.screenWatcher:start()

ws.windowFilter = window.filter.new()
ws.windowFilter:subscribe(window.filter.windowFocused, function()
  ws.updateMenubar()
end)

alert.show("Space Labels loaded! 🏷️")
print("Space Labels script loaded successfully!")
