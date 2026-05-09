-- Brief alert banner showing the current space's label, or "No label" if
-- none. Triggered by ⌘⌃L.
local alert = require("hs.alert")
local labels = require("actions.labels")

local M = {}

function M.show()
  local k = labels.currentKey()
  if not k then alert.show("No active space"); return end
  alert.show(labels.getCurrentLabel() or "No label for this space")
end

return M
