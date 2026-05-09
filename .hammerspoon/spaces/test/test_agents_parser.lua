local h = require("_helpers")
local agents = require("core.agents")

-- Happy path: tagged title with state and freeform subject.
local p = agents.parseTitle("[spaces:run] orca:fix-flake")
h.assert_eq(p.state, "run", "run state parsed")
h.assert_eq(p.title, "orca:fix-flake", "title freeform parsed")

p = agents.parseTitle("[spaces:wait] keel:review")
h.assert_eq(p.state, "wait", "wait state")

p = agents.parseTitle("[spaces:done]")
h.assert_eq(p.state, "done", "state with empty title")
h.assert_eq(p.title, "", "empty title")

-- Unknown state name falls back to idle, raw title kept.
p = agents.parseTitle("[spaces:bogus] x")
h.assert_eq(p.state, "idle", "unknown state -> idle")
h.assert_eq(p.title, "[spaces:bogus] x", "raw title preserved on unknown state")

-- Untagged title: idle, raw kept.
p = agents.parseTitle("zsh — ~")
h.assert_eq(p.state, "idle", "untagged -> idle")
h.assert_eq(p.title, "zsh — ~", "raw kept")

-- Empty/nil
p = agents.parseTitle("")
h.assert_eq(p.state, "idle", "empty -> idle")
h.assert_eq(p.title, "", "empty title kept")

p = agents.parseTitle(nil)
h.assert_eq(p.state, "idle", "nil -> idle")
h.assert_eq(p.title, "", "nil -> empty title")

-- All five canonical states
for _, s in ipairs({ "idle", "run", "wait", "done", "err" }) do
  p = agents.parseTitle("[spaces:" .. s .. "] x")
  h.assert_eq(p.state, s, s .. " state")
end
