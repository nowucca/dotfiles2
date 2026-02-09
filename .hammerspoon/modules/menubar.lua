-- ============================================
-- MENUBAR MODULE
-- Menubar widget for space labels
-- ============================================

local M = {}

local menubar = require("hs.menubar")
local spaces = require("hs.spaces")
local screen = require("hs.screen")
local window = require("hs.window")
local timer = require("hs.timer")
local data = require("modules.data")

-- Dependencies (set during init)
local spaceLabels = nil
local spaceSwitcher = nil
local profiles = nil

-- Internal state
M.widget = nil
M.spaceWatcher = nil
M.screenWatcher = nil
M.windowFilter = nil

function M.update()
  if not M.widget then return end

  local label = spaceLabels and spaceLabels.getCurrentLabel() or nil
  if label then
    M.widget:setTitle("🏷️ " .. label)
  else
    M.widget:setTitle("🏷️")
  end
end

function M.buildMenu()
  local menu = {}
  local d = data.load()
  local key = spaceLabels and spaceLabels.currentKey() or nil
  local currentLabel = key and data.getLabelForSpace(d, key) or nil

  -- Current info
  if currentLabel then
    table.insert(menu, { title = "Current: " .. currentLabel, disabled = true })
  else
    table.insert(menu, { title = "Current: (unlabeled)", disabled = true })
  end
  table.insert(menu, { title = "-" })

  -- Actions
  table.insert(menu, {
    title = "Set Label... (⌘⌃L)",
    fn = function() if spaceLabels then spaceLabels.promptForLabel() end end
  })

  table.insert(menu, {
    title = "Switch Space... (⌘⌃Space)",
    fn = function() if spaceSwitcher then spaceSwitcher.show() end end
  })

  if currentLabel then
    table.insert(menu, {
      title = "Clear Label",
      fn = function() if spaceLabels then spaceLabels.clear() end end
    })
  end

  -- Collect all labels
  local sortedLabels = data.getAllLabels()

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
          local newKey = spaceLabels and spaceLabels.currentKey() or nil
          if newKey then
            local d = data.load()
            data.setLabelForSpace(d, newKey, labelName)
            data.save(d)
            hs.alert.show("Space labeled: " .. labelName)
            M.update()
          end
        end
      })
    end
  end

  -- Management section
  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Delete a Label...",
    fn = function() if spaceLabels then spaceLabels.showDeleteLabelChooser() end end
  })
  table.insert(menu, {
    title = "Prune Labels",
    menu = {
      {
        title = "Older than 7 days",
        fn = function() if spaceLabels then spaceLabels.pruneLabels(7) end end
      },
      {
        title = "Older than 30 days",
        fn = function() if spaceLabels then spaceLabels.pruneLabels(30) end end
      },
      {
        title = "Older than 90 days",
        fn = function() if spaceLabels then spaceLabels.pruneLabels(90) end end
      }
    }
  })

  -- Profiles section
  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "Space Profiles:", disabled = true })
  table.insert(menu, {
    title = "Save Space Profile... (⌘⌃S)",
    fn = function() if profiles then profiles.promptSaveCurrentSpace() end end
  })
  table.insert(menu, {
    title = "Restore Profile... (⌘⌃R)",
    fn = function() if profiles then profiles.showRestoreChooser() end end
  })
  table.insert(menu, {
    title = "Delete Profile...",
    fn = function() if profiles then profiles.showDeleteChooser() end end
  })

  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Show Banner (⌘⌃⇧L)",
    fn = function() if spaceLabels then spaceLabels.show() end end
  })
  table.insert(menu, {
    title = "Debug Info",
    fn = function() if spaceLabels then spaceLabels.debug() end end
  })

  return menu
end

function M.init(deps)
  -- Store dependencies
  spaceLabels = deps.spaceLabels
  spaceSwitcher = deps.spaceSwitcher
  profiles = deps.profiles

  -- Create menubar widget
  if M.widget then
    M.widget:delete()
    M.widget = nil
  end

  M.widget = menubar.new(true, "SpaceLabels")
  if M.widget then
    M.widget:setMenu(M.buildMenu)
    M.update()
    print("Menubar created (Cmd+drag to reposition)")
  else
    print("ERROR: menubar.new() returned nil")
  end

  -- Set up callbacks
  if spaceLabels then
    spaceLabels.onLabelChanged = M.update
  end
  if spaceSwitcher then
    spaceSwitcher.onSpaceChanged = M.update
  end

  -- Start watchers
  M.spaceWatcher = spaces.watcher.new(function()
    M.update()
  end)
  M.spaceWatcher:start()

  M.screenWatcher = screen.watcher.new(function()
    timer.doAfter(0.5, function()
      M.update()
    end)
  end)
  M.screenWatcher:start()

  M.windowFilter = window.filter.new()
  M.windowFilter:subscribe(window.filter.windowFocused, function()
    M.update()
  end)
end

function M.stop()
  if M.spaceWatcher then M.spaceWatcher:stop() end
  if M.screenWatcher then M.screenWatcher:stop() end
  if M.windowFilter then M.windowFilter:unsubscribeAll() end
  if M.widget then
    M.widget:delete()
    M.widget = nil
  end
end

return M
