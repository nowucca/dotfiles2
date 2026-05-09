-- Four launcher actions:
--   openChrome / openITerm — preserve existing ⌘⌃B / ⌘⌃T behaviour
--   newAgentSpace          — ⌘⌃A: new space, label, cwd chooser, claude
--   newAgentTabHere        — ⌘⌃⇧A: new tab on current space, claude
local spaces = require("hs.spaces")
local screenMod = require("hs.screen")
local windowMod = require("hs.window")
local chooserMod = require("hs.chooser")
local dialog = require("hs.dialog")
local alert = require("hs.alert")
local log = require("core.log")
local data = require("core.data")
local iterm = require("core.iterm")
local chrome = require("core.chrome")
local labels = require("actions.labels")

local M = {}
M.onWindowLaunched = nil  -- menubar subscribes to refresh on launch

local DEFAULT_AGENT_COMMAND = "claude"

local function currentSpaceInfo()
  local win = windowMod.focusedWindow()
  local scr = (win and win:screen()) or screenMod.mainScreen()
  if not scr then return nil, nil end
  return spaces.activeSpaces()[scr:getUUID()], scr
end

-- Find an iTerm window currently on the given space, if any.
local function itermWindowOnSpace(sid)
  for _, w in ipairs(iterm.snapshot().windows) do
    if w.space == sid then return w end
  end
  return nil
end

-- Show a chooser populated from data.agentCwds (most recent first), with a
-- final "Choose other..." entry that opens a folder picker. Calls cb(path)
-- or cb(nil) if dismissed.
local function chooseCwd(cb)
  local d = data.load()
  local recents = d.agentCwds or {}
  local choices = {}
  for _, p in ipairs(recents) do
    table.insert(choices, { text = p, subText = "recent", path = p })
  end
  table.insert(choices, {
    text = "Choose other...",
    subText = "open a folder picker",
    other = true,
  })
  chooserMod.new(function(choice)
    if not choice then cb(nil); return end
    if choice.other then
      local picked = dialog.chooseFileOrFolder("Choose working directory",
        os.getenv("HOME"), false, true, false)
      -- chooseFileOrFolder returns a table whose values are the chosen paths.
      local path = nil
      if picked then for _, v in pairs(picked) do path = v; break end end
      cb(path)
    else
      cb(choice.path)
    end
  end):choices(choices):placeholderText("Working directory for the agent..."):show()
end

-- Persist the chosen path to the recents list and save.
local function rememberCwd(path)
  if not path then return end
  local d = data.load()
  data.pushAgentCwd(d, path)
  data.save(d)
end

function M.openChrome()
  local sid, scr = currentSpaceInfo()
  if not sid then alert.show("Cannot determine current space"); return end
  chrome.openWindowOnSpace(sid, scr)
  if M.onWindowLaunched then M.onWindowLaunched() end
end

function M.openITerm()
  local sid, scr = currentSpaceInfo()
  if not sid then alert.show("Cannot determine current space"); return end
  iterm.newWindow({ cwd = os.getenv("HOME") })
  if M.onWindowLaunched then M.onWindowLaunched() end
end

function M.showLauncher()
  chooserMod.new(function(choice)
    if not choice then return end
    if choice.app == "chrome" then M.openChrome()
    elseif choice.app == "iterm" then M.openITerm() end
  end):choices({
    { text = "Chrome", subText = "Open Chrome on this space", app = "chrome" },
    { text = "iTerm",  subText = "Open iTerm on this space",  app = "iterm" },
  }):placeholderText("Launch on current space..."):show()
end

function M.newAgentSpace()
  local _, scr = currentSpaceInfo()
  scr = scr or screenMod.mainScreen()
  if not scr then alert.show("No screen"); return end

  local button, labelName = dialog.textPrompt("New Agent Space", "Label for the new space:", "", "Create", "Cancel")
  if button ~= "Create" then return end

  chooseCwd(function(path)
    if not path then alert.show("Cancelled"); return end
    rememberCwd(path)

    -- Capture before-set, create the space.
    local before = {}
    for _, s in ipairs(spaces.spacesForScreen(scr) or {}) do before[s] = true end
    if not spaces.addSpaceToScreen(scr, true) then alert.show("Failed to create space"); return end

    require("hs.timer").doAfter(0.6, function()
      local newSid
      for _, s in ipairs(spaces.spacesForScreen(scr) or {}) do
        if not before[s] then newSid = s; break end
      end
      if not newSid then alert.show("Could not find new space"); return end

      if labelName and labelName ~= "" then
        log.try(function()
          local d = data.load()
          data.setLabelForSpace(d, tostring(newSid), labelName)
          data.save(d)
        end, "set label on new agent space")
      end

      log.try(function() spaces.gotoSpace(newSid) end, "goto new agent space")

      require("hs.timer").doAfter(0.8, function()
        iterm.newWindow({
          cwd = path,
          command = DEFAULT_AGENT_COMMAND,
          title = "[spaces:idle] " .. (labelName or "agent"),
        })
        if M.onWindowLaunched then M.onWindowLaunched() end
      end)
    end)
  end)
end

function M.newAgentTabHere()
  local sid = currentSpaceInfo()
  if not sid then alert.show("Cannot determine current space"); return end

  chooseCwd(function(path)
    if not path then alert.show("Cancelled"); return end
    rememberCwd(path)

    local label = labels.getCurrentLabel() or "agent"
    local existing = itermWindowOnSpace(sid)
    if existing then
      iterm.newTab(existing.id, {
        cwd = path,
        command = DEFAULT_AGENT_COMMAND,
        title = "[spaces:idle] " .. label,
      })
    else
      iterm.newWindow({
        cwd = path,
        command = DEFAULT_AGENT_COMMAND,
        title = "[spaces:idle] " .. label,
      })
    end
    if M.onWindowLaunched then M.onWindowLaunched() end
  end)
end

return M
