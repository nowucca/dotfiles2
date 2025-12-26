require("hs.ipc")

spaces = require("hs.spaces")
json   = require("hs.json")

ws = {}

function ws.debug()
  local win = hs.window.focusedWindow()
  if not win then
    hs.alert.show("No focused window")
    return
  end

  local screenUUID = win:screen():getUUID()
  local spaceID = spaces.activeSpaces()[screenUUID]

  hs.alert.show(
    "Screen: " .. screenUUID .. "\nSpace: " .. tostring(spaceID)
  )
end


local notesPath = hs.configdir .. "/workspace-notes.json"

local function loadNotes()
  if hs.fs.attributes(notesPath) then
    return json.decode(io.open(notesPath):read("*a")) or {}
  end
  return {}
end

local function saveNotes(notes)
  local f = io.open(notesPath, "w")
  f:write(json.encode(notes, true))
  f:close()
end


function ws.currentKey()
  local win = hs.window.focusedWindow()
  if not win then return nil end

  local screenUUID = win:screen():getUUID()
  local spaceID = spaces.activeSpaces()[screenUUID]
  if not spaceID then return nil end

  return screenUUID .. ":" .. tostring(spaceID)
end

function ws.show()
  local key = ws.currentKey()
  if not key then
    hs.alert.show("No active space")
    return
  end

  local notes = loadNotes()
  hs.alert.show(notes[key] or "No note for this Space")
end

function ws.set(text)
  if not text or text == "" then return end

  local key = ws.currentKey()
  if not key then return end

  local notes = loadNotes()
  notes[key] = text
  saveNotes(notes)

  hs.alert.show("Space note saved")
end

function ws.rebind()
  local notes = loadNotes()
  local choices = {}

  for k, v in pairs(notes) do
    table.insert(choices, {
      text = v,
      subText = k,
      key = k
    })
  end

  hs.chooser.new(function(choice)
    if not choice then return end

    local newKey = ws.currentKey()
    if not newKey then return end

    notes[newKey] = notes[choice.key]
    saveNotes(notes)

    hs.alert.show("Space note rebound")
  end):choices(choices):show()
end


