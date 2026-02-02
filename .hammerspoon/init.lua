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
-- NOTES PERSISTENCE
-- ============================================

local notesPath = hs.configdir .. "/workspace-notes.json"

local function loadNotes()
  if fs.attributes(notesPath) then
    local f = io.open(notesPath)
    if f then
      local content = f:read("*a")
      f:close()
      return json.decode(content) or {}
    end
  end
  return {}
end

local function saveNotes(notes)
  local f = io.open(notesPath, "w")
  if f then
    f:write(json.encode(notes, true))
    f:close()
  end
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
    -- Fall back to main screen if no focused window
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

  local notes = loadNotes()
  alert.show(notes[key] or "No note for this Space")
end

function ws.set(text)
  if not text or text == "" then return end

  local key = ws.currentKey()
  if not key then return end

  local notes = loadNotes()
  notes[key] = text
  saveNotes(notes)

  alert.show("Space note saved: " .. text)
  ws.updateMenubar()
end

function ws.rebind()
  local notes = loadNotes()
  local choices = {}

  -- Collect unique labels (just label names, no space IDs)
  local seenLabels = {}
  for k, v in pairs(notes) do
    if not seenLabels[v] then
      seenLabels[v] = true
      table.insert(choices, {
        text = v,
        subText = "Click to apply this label to current space",
        label = v
      })
    end
  end

  chooser.new(function(choice)
    if not choice then return end

    local newKey = ws.currentKey()
    if not newKey then return end

    local notes = loadNotes()
    notes[newKey] = choice.label
    saveNotes(notes)

    alert.show("Space labeled: " .. choice.label)
    ws.updateMenubar()
  end):choices(choices):show()
end

-- ============================================
-- MENUBAR WIDGET
-- ============================================

function ws.getCurrentLabel()
  local key = ws.currentKey()
  if not key then return nil end
  local notes = loadNotes()
  return notes[key]
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

  local notes = loadNotes()
  if notes[key] then
    notes[key] = nil
    saveNotes(notes)
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
  local notes = loadNotes()
  local key = ws.currentKey()
  local currentLabel = key and notes[key] or nil

  -- Current info (simplified)
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

  -- Collect unique labels for quick apply
  local seenLabels = {}
  local uniqueLabels = {}
  for k, v in pairs(notes) do
    if not seenLabels[v] then
      seenLabels[v] = true
      table.insert(uniqueLabels, v)
    end
  end

  if #uniqueLabels > 0 then
    table.insert(menu, { title = "-" })
    table.insert(menu, { title = "Apply Existing Label:", disabled = true })

    for _, labelName in ipairs(uniqueLabels) do
      local isCurrent = (labelName == currentLabel)
      table.insert(menu, {
        title = (isCurrent and "→ " or "   ") .. labelName,
        fn = function()
          local newKey = ws.currentKey()
          if newKey then
            local notes = loadNotes()
            notes[newKey] = labelName
            saveNotes(notes)
            alert.show("Space labeled: " .. labelName)
            ws.updateMenubar()
          end
        end
      })
    end
  end

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

  ws.menubar = menubar.new()
  if ws.menubar then
    ws.menubar:setMenu(ws.buildMenu)
    ws.updateMenubar()
    print("Menubar created")
  else
    print("ERROR: menubar.new() returned nil")
  end
end

-- ============================================
-- WATCHERS
-- ============================================

-- Watch for space changes - update immediately
ws.spaceWatcher = spaces.watcher.new(function()
  ws.updateMenubar()
end)

-- Watch for screen changes
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

-- Watch window focus for faster updates
ws.windowFilter = window.filter.new()
ws.windowFilter:subscribe(window.filter.windowFocused, function()
  ws.updateMenubar()
end)

alert.show("Space Labels loaded! 🏷️")
print("Space Labels script loaded successfully!")
