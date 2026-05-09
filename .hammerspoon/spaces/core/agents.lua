-- Agent state tracking. v1 of this file ships only the title parser; the
-- in-memory state map and polling loop arrive in Task 9.
local M = {}

local VALID_STATES = { idle = true, run = true, wait = true, done = true, err = true }

-- Parse an iTerm tab title. Returns { state, title }.
-- Convention: "[spaces:STATE] FREEFORM" where STATE is one of the canonical
-- states. Anything else returns state="idle" with the raw title preserved.
function M.parseTitle(raw)
  if raw == nil or raw == "" then return { state = "idle", title = "" } end
  local state, rest = raw:match("^%[spaces:(%a+)%]%s*(.*)$")
  if state and VALID_STATES[state] then
    return { state = state, title = rest or "" }
  end
  return { state = "idle", title = raw }
end

return M
