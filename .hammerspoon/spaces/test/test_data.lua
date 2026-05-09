local h = require("_helpers")
local data = require("core.data")

-- validateAndClean: drops malformed entries, lifts misplaced label-strings.
local cleaned = data._validateAndClean({
  labels = { Foo = { lastUsed = 100 }, Bad = "string-not-table" },
  spaces = { ["123"] = "Foo", ["456"] = { not_a_string = true } },
})
h.assert_eq(cleaned.labels.Foo.lastUsed, 100, "good label kept")
h.assert_nil(cleaned.labels.Bad, "bad label dropped")
h.assert_eq(cleaned.spaces["123"], "Foo", "good space kept")
h.assert_nil(cleaned.spaces["456"], "table-valued space dropped")

-- agentCwds: prepended on add, capped at 10, deduped.
local d = { agentCwds = { "/a", "/b", "/c" } }
data.pushAgentCwd(d, "/b")  -- already present, moves to front
h.assert_eq(d.agentCwds[1], "/b", "existing entry moves to front")
h.assert_eq(#d.agentCwds, 3, "no duplicate added")

data.pushAgentCwd(d, "/new")
h.assert_eq(d.agentCwds[1], "/new", "new entry at front")
h.assert_eq(#d.agentCwds, 4, "list grew")

-- Capacity test: fill to 12, expect cap at 10.
d = { agentCwds = {} }
for i = 1, 12 do data.pushAgentCwd(d, "/p" .. i) end
h.assert_eq(#d.agentCwds, 10, "capped at 10")
h.assert_eq(d.agentCwds[1], "/p12", "newest at front")
h.assert_eq(d.agentCwds[10], "/p3", "oldest dropped")

-- formatDaysAgo: pure formatter.
h.assert_eq(data.formatDaysAgo(os.time()), "today", "today")
h.assert_eq(data.formatDaysAgo(os.time() - 86400), "yesterday", "yesterday")
h.assert_eq(data.formatDaysAgo(os.time() - 86400 * 5), "5 days ago", "5 days")

-- setLabelForSpace updates lastUsed on the label.
d = { labels = {}, spaces = {} }
data.setLabelForSpace(d, "42", "Project X")
h.assert_eq(d.spaces["42"], "Project X", "space mapped")
h.assert_true(d.labels["Project X"].lastUsed > 0, "label has lastUsed")
