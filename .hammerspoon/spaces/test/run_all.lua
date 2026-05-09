-- Run with: hs -c "dofile(hs.configdir .. '/spaces/test/run_all.lua')"
package.path = hs.configdir .. "/spaces/?.lua;"
            .. hs.configdir .. "/spaces/?/init.lua;"
            .. hs.configdir .. "/spaces/test/?.lua;"
            .. package.path

local h = require("_helpers")
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
