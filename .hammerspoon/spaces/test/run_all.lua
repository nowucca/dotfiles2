-- Run with: hs -c "dofile(hs.configdir .. '/spaces/test/run_all.lua')"
package.path = hs.configdir .. "/spaces/?.lua;"
            .. hs.configdir .. "/spaces/?/init.lua;"
            .. hs.configdir .. "/spaces/test/?.lua;"
            .. package.path

-- Hammerspoon's Lua state is persistent across `hs -c` invocations. Force a
-- fresh _helpers module each run so counters don't accumulate.
package.loaded["_helpers"] = nil
local h = require("_helpers")

-- Drop any cached test modules from prior runs so they're re-executed against
-- the current code (a test_*.lua may have been edited since the last run).
for name in pairs(package.loaded) do
  if name:match("^test_") then package.loaded[name] = nil end
end

local fs = require("hs.fs")
local testDir = hs.configdir .. "/spaces/test"

local files = {}
for file in fs.dir(testDir) do
  if file:match("^test_.*%.lua$") then table.insert(files, file) end
end
table.sort(files)

for _, file in ipairs(files) do
  h.section(file)
  dofile(testDir .. "/" .. file)
end

h.summary()
