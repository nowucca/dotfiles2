-- Label data operations: set/clear/prune/getCurrentLabel/promptForLabel/rebind.
-- The banner display is in ui/banner.lua. Behaviour mirrors the existing
-- modules/space-labels.lua exactly; only the file location changed.
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local dialog = require("hs.dialog")
local chooser = require("hs.chooser")
local alert = require("hs.alert")
local data = require("core.data")
local log = require("core.log")

local M = {}
M.onLabelChanged = nil

local function currentKey()
  local win = windowMod.focusedWindow()
  local scr = (win and win:screen()) or screenMod.mainScreen()
  if not scr then return nil end
  local id = spaces.activeSpaces()[scr:getUUID()]
  return id and tostring(id) or nil
end

M.currentKey = currentKey

function M.getCurrentLabel()
  local k = currentKey()
  if not k then return nil end
  return data.getLabelForSpace(data.load(), k)
end

function M.set(text)
  if not text or text == "" then return end
  local k = currentKey()
  if not k then return end
  local d = data.load()
  data.setLabelForSpace(d, k, text)
  data.save(d)
  alert.show("Labelled " .. text)
  if M.onLabelChanged then M.onLabelChanged() end
end

function M.clear()
  local k = currentKey()
  if not k then return end
  local d = data.load()
  if d.spaces[k] then
    d.spaces[k] = nil
    data.save(d)
    alert.show("Cleared label")
    if M.onLabelChanged then M.onLabelChanged() end
  end
end

function M.promptForLabel()
  local current = M.getCurrentLabel() or ""
  local button, text = dialog.textPrompt("Label This Space", "Enter a label for the current space:", current, "Save", "Cancel")
  if button == "Save" and text and text ~= "" then M.set(text) end
end

function M.rebind()
  local d = data.load()
  local choices = {}
  for name, meta in pairs(d.labels) do
    table.insert(choices, { text = name, subText = "Last used: " .. data.formatDaysAgo(meta.lastUsed), label = name })
  end
  table.sort(choices, function(a, b) return string.lower(a.text) < string.lower(b.text) end)

  chooser.new(function(choice)
    if not choice then return end
    local k = currentKey()
    if not k then return end
    local dd = data.load()
    data.setLabelForSpace(dd, k, choice.label)
    data.save(dd)
    alert.show("Labelled " .. choice.label)
    if M.onLabelChanged then M.onLabelChanged() end
  end):choices(choices):show()
end

function M.pruneLabels(daysOld)
  daysOld = daysOld or 30
  local d = data.load()
  local cutoff = os.time() - (daysOld * 86400)
  local pruned = {}
  for name, meta in pairs(d.labels) do
    if (meta.lastUsed or 0) < cutoff then table.insert(pruned, name) end
  end
  if #pruned == 0 then alert.show("No labels older than " .. daysOld .. " days"); return end
  for _, name in ipairs(pruned) do
    d.labels[name] = nil
    for sid, lbl in pairs(d.spaces) do if lbl == name then d.spaces[sid] = nil end end
  end
  data.save(d)
  alert.show("Pruned " .. #pruned .. " labels")
  log.info("labels: pruned " .. table.concat(pruned, ", "))
  if M.onLabelChanged then M.onLabelChanged() end
end

function M.deleteLabel(name)
  local d = data.load()
  if not d.labels[name] then alert.show("Label not found"); return end
  d.labels[name] = nil
  for sid, lbl in pairs(d.spaces) do if lbl == name then d.spaces[sid] = nil end end
  data.save(d)
  alert.show("Deleted " .. name)
  if M.onLabelChanged then M.onLabelChanged() end
end

function M.showDeleteLabelChooser()
  local d = data.load()
  local choices = {}
  for name, meta in pairs(d.labels) do
    table.insert(choices, { text = name, subText = "Last used: " .. data.formatDaysAgo(meta.lastUsed), label = name })
  end
  table.sort(choices, function(a, b) return string.lower(a.text) < string.lower(b.text) end)
  chooser.new(function(choice)
    if not choice then return end
    M.deleteLabel(choice.label)
  end):choices(choices):placeholderText("Select label to delete"):show()
end

return M
