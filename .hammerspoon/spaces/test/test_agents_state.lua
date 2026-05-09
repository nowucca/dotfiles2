local h = require("_helpers")
local agents = require("core.agents")

-- The state map is keyed by (spaceId, winId, tabId) and updates from a
-- snapshot. We feed it a fake snapshot to avoid needing iTerm.
local fake = {
  windows = {
    { id = 100, space = 1, tabs = {
      { id = 1001, index = 1, title = "[spaces:run] task-a", isProcessing = true },
      { id = 1002, index = 2, title = "shell", isProcessing = false },
    }},
    { id = 101, space = 2, tabs = {
      { id = 1003, index = 1, title = "[spaces:done]", isProcessing = false },
    }},
  },
}

local changes = {}
agents.onChange = function(prev, next) table.insert(changes, { prev = prev, next = next }) end

agents._refreshFromSnapshot(fake)
local s = agents.summary()
h.assert_eq(s.run, 1, "summary run")
h.assert_eq(s.done, 1, "summary done")
h.assert_eq(s.idle, 1, "summary idle")
h.assert_eq(s.wait, 0, "summary wait")
h.assert_eq(s.err, 0, "summary err")

local rec = agents.get(1, 100, 1001)
h.assert_eq(rec.state, "run", "tab 1001 state")
h.assert_eq(rec.title, "task-a", "tab 1001 title")
h.assert_eq(rec.tabIndex, 1, "tab 1001 tabIndex carried through")

-- Second refresh with a state change should fire onChange.
fake.windows[1].tabs[1].title = "[spaces:done] task-a"
changes = {}
agents._refreshFromSnapshot(fake)
h.assert_true(#changes >= 1, "state change fired onChange")
local last = changes[#changes]
h.assert_eq(last.prev.state, "run", "prev state run")
h.assert_eq(last.next.state, "done", "next state done")

-- A tab disappearing from the snapshot is removed from the map.
fake.windows[1].tabs = { fake.windows[1].tabs[2] }  -- drop tab 1001
agents._refreshFromSnapshot(fake)
h.assert_nil(agents.get(1, 100, 1001), "missing tab pruned")

agents.onChange = nil  -- reset for any later tests in the same run
