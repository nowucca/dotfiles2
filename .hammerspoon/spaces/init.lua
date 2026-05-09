-- Spaces product entry point. Owns hotkey registration, agent polling,
-- the menubar widget, and the ws.spaces console namespace.
local hotkey = require("hs.hotkey")
local config = require("core.config")
local log = require("core.log")
local agents = require("core.agents")
local labels = require("actions.labels")
local manager = require("actions.space-manager")
local profiles = require("actions.profiles")
local launcher = require("actions.launcher")
local switcher = require("ui.switcher")
local banner = require("ui.banner")
local menubar = require("ui.menubar")
local iterm = require("core.iterm")

local M = { name = config.brand.name, version = config.brand.version }
M._hotkeys = {}

local function bind(mods, key, fn)
  local h = hotkey.bind(mods, key, fn)
  table.insert(M._hotkeys, h)
end

function M.start()
  log.info(string.format("%s %s starting", config.brand.name, config.brand.version))

  agents.start()
  menubar.start()

  -- New (v1) agent launchers.
  bind({"cmd", "ctrl"}, "A",            function() launcher.newAgentSpace() end)
  bind({"cmd", "ctrl", "shift"}, "A",   function() launcher.newAgentTabHere() end)

  -- Existing space hotkeys.
  bind({"cmd", "ctrl"}, "L",            function() banner.show() end)
  bind({"cmd", "ctrl", "shift"}, "L",   function() labels.promptForLabel() end)
  bind({"cmd", "ctrl"}, "space",        function() switcher.show() end)
  bind({"cmd", "ctrl"}, "S",            function() profiles.promptSaveCurrentSpace() end)
  bind({"cmd", "ctrl"}, "R",            function() profiles.showRestoreChooser() end)
  bind({"cmd", "ctrl"}, "N",            function() launcher.showLauncher() end)
  bind({"cmd", "ctrl"}, "B",            function() launcher.openChrome() end)
  bind({"cmd", "ctrl"}, "T",            function() launcher.openITerm() end)
  bind({"cmd", "ctrl", "shift"}, "N",   function() manager.createNewSpace() end)
  bind({"cmd", "ctrl", "shift"}, "C",   function() manager.confirmCloseCurrentSpace() end)

  -- Console debug namespace. Replaces the old flat ws.* shortcuts.
  _G.ws = _G.ws or {}
  _G.ws.spaces = {
    config = config, log = log, agents = agents, iterm = iterm,
    labels = labels, switcher = switcher, banner = banner,
    manager = manager, profiles = profiles, launcher = launcher,
    menubar = menubar,
  }

  local s = agents.summary()
  log.info(string.format("%s %s ready · %d agents", config.brand.name, config.brand.version, s.run + s.wait + s.done + s.err))
end

function M.stop()
  for _, h in ipairs(M._hotkeys) do h:delete() end
  M._hotkeys = {}
  menubar.stop()
  agents.stop()
  if _G.ws then _G.ws.spaces = nil end
  log.info(config.brand.name .. " stopped")
end

return M
