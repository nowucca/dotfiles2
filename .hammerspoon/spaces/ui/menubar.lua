-- Branded menubar widget for the Spaces product. Shape:
--   [glyph] [label] [optional state dot]   ← widget title
--
--   ▶ <current space>          (expanded inline)
--     ▶ iTerm — Window N
--         ● task title         (clickable: focuses tab)
--         shell
--      <other space>           (click to switch)
--
--   New agent space…           ⌘⌃A
--   New agent tab here         ⌘⌃⇧A
--   ─────
--   Set Label…                 ⌘⌃⇧L
--   New Space                  ⌘⌃⇧N
--   Close Space                ⌘⌃⇧C
--   ─────
--   Open Chrome                ⌘⌃B
--   Open iTerm                 ⌘⌃T
--   ─────
--   Profiles ▸                 (existing submenu)
--   Manage Labels ▸            (existing submenu)
--   ─────
--   About Spaces…
local menubarMod = require("hs.menubar")
local image = require("hs.image")
local spacesMod = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local timer = require("hs.timer")
local config = require("core.config")
local log = require("core.log")
local agents = require("core.agents")
local labels = require("actions.labels")
local switcher = require("ui.switcher")
local manager = require("actions.space-manager")
local profiles = require("actions.profiles")
local launcher = require("actions.launcher")
local about = require("ui.about")
local iterm = require("core.iterm")

local STATE_GLYPHS = { run = "●", wait = "◐", done = "○", err = "✕", idle = "" }

local M = {}
M._widget = nil
M._spaceWatcher = nil
M._screenWatcher = nil
M._winFilter = nil

local function brandImage()
  local img = image.imageFromName("symbol://" .. config.brand.glyph)
  if img then img:setSize({ w = 18, h = 18 }) ; img:template(true) end
  return img
end

local function currentSpaceId()
  local win = windowMod.focusedWindow()
  local scr = (win and win:screen()) or screenMod.mainScreen()
  if not scr then return nil end
  return spacesMod.activeSpaces()[scr:getUUID()]
end

-- Update widget title based on current space + agent state on it.
local function updateTitle()
  if not M._widget then return end
  local sid = currentSpaceId()
  local label = labels.getCurrentLabel()
  local title = label or ""

  -- Current-space agent badge: prefer run, then wait, else nothing.
  local badge = ""
  if sid then
    local recs = agents.forSpace(sid)
    local hasRun, hasWait = false, false
    for _, r in ipairs(recs) do
      if r.state == "run" then hasRun = true end
      if r.state == "wait" then hasWait = true end
    end
    if hasRun then badge = " ●"
    elseif hasWait then badge = " ◐" end
  end

  if title == "" and badge == "" then
    M._widget:setTitle("")
  else
    M._widget:setTitle(title .. badge)
  end
end

-- Build a clickable row for a single iTerm tab. Walks the live snapshot
-- entry to get index (for focus) plus the parsed agent state (for badge).
local function tabRow(winId, tab, spaceId)
  local rec = agents.get(spaceId, winId, tab.id) or { state = "idle", title = tab.title }
  local glyph = STATE_GLYPHS[rec.state] or ""
  local subject = rec.title ~= "" and rec.title or "(shell)"
  local prefix = (glyph ~= "" and glyph or "·") .. "  "
  local idx = tab.index
  return {
    title = "      " .. prefix .. subject,
    fn = function()
      log.try(function() iterm.focusTab(winId, idx) end, "menubar.focusTab")
    end,
  }
end

local function buildSpaceSection()
  local out = {}
  local sid = currentSpaceId()
  local switcherItems = switcher.getSpacesForCurrentScreen()
  local snap = iterm.snapshot()

  for _, info in ipairs(switcherItems) do
    local title = info.label or ("Space " .. info.index)
    if info.isActive then
      table.insert(out, { title = "▶ " .. title .. "  (current)", disabled = true })
      -- Iterate windows on this space, group tabs by window.
      local winNum = 0
      for _, w in ipairs(snap.windows) do
        if w.space == sid then
          winNum = winNum + 1
          table.insert(out, { title = "   ▶ iTerm — Window " .. winNum, disabled = true })
          for _, t in ipairs(w.tabs) do
            table.insert(out, tabRow(w.id, t, sid))
          end
        end
      end
    else
      table.insert(out, {
        title = "   " .. title,
        fn = function() switcher.gotoSpace(info.spaceId) end,
      })
    end
  end
  return out
end

local function buildMenu()
  local menu = {}
  for _, item in ipairs(buildSpaceSection()) do table.insert(menu, item) end

  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "New agent space…       ⌘⌃A", fn = function() launcher.newAgentSpace() end })
  table.insert(menu, { title = "New agent tab here    ⌘⌃⇧A", fn = function() launcher.newAgentTabHere() end })

  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "Set Label…              ⌘⌃⇧L", fn = function() labels.promptForLabel() end })
  table.insert(menu, { title = "New Space               ⌘⌃⇧N", fn = function() manager.createNewSpace() end })
  table.insert(menu, { title = "Close Space             ⌘⌃⇧C", fn = function() manager.confirmCloseCurrentSpace() end })

  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "Open Chrome             ⌘⌃B", fn = function() launcher.openChrome() end })
  table.insert(menu, { title = "Open iTerm              ⌘⌃T", fn = function() launcher.openITerm() end })

  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Profiles",
    menu = {
      { title = "Save Profile…   ⌘⌃S", fn = function() profiles.promptSaveCurrentSpace() end },
      { title = "Restore Profile…  ⌘⌃R", fn = function() profiles.showRestoreChooser() end },
      { title = "Delete Profile…", fn = function() profiles.showDeleteChooser() end },
    },
  })
  table.insert(menu, {
    title = "Manage Labels",
    menu = {
      { title = "Apply Existing Label…", fn = function() labels.rebind() end },
      { title = "Clear Current Label",   fn = function() labels.clear() end },
      { title = "-" },
      { title = "Delete a Label…",       fn = function() labels.showDeleteLabelChooser() end },
      { title = "Prune Older than 7d",   fn = function() labels.pruneLabels(7) end },
      { title = "Prune Older than 30d",  fn = function() labels.pruneLabels(30) end },
    },
  })

  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "About " .. config.brand.name .. "…", fn = function() about.show() end })

  return menu
end

function M.update()
  updateTitle()
end

function M.start()
  if M._widget then M._widget:delete() end
  M._widget = menubarMod.new(true, "Spaces")
  if not M._widget then log.error("menubar: hs.menubar.new returned nil"); return end

  local img = brandImage()
  if img then M._widget:setIcon(img)
  else log.warn("menubar: SF Symbol unavailable, using text-only title") end

  M._widget:setMenu(buildMenu)
  updateTitle()

  -- Update widget title on space switches and label changes.
  labels.onLabelChanged = updateTitle
  switcher.onSpaceChanged = updateTitle
  launcher.onWindowLaunched = updateTitle
  agents.onChange = updateTitle

  M._spaceWatcher = spacesMod.watcher.new(function() updateTitle() end)
  M._spaceWatcher:start()

  M._screenWatcher = screenMod.watcher.new(function()
    timer.doAfter(0.5, updateTitle)
  end)
  M._screenWatcher:start()

  M._winFilter = windowMod.filter.new()
  M._winFilter:subscribe(windowMod.filter.windowFocused, function() updateTitle() end)
end

function M.stop()
  if M._widget then M._widget:delete(); M._widget = nil end
  if M._spaceWatcher then M._spaceWatcher:stop(); M._spaceWatcher = nil end
  if M._screenWatcher then M._screenWatcher:stop(); M._screenWatcher = nil end
  if M._winFilter then M._winFilter:unsubscribeAll(); M._winFilter = nil end
  labels.onLabelChanged = nil
  switcher.onSpaceChanged = nil
  launcher.onWindowLaunched = nil
  agents.onChange = nil
end

return M
