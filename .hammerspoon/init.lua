-- Hammerspoon host. Loads each product listed in products.lua and calls
-- its start(). Exposes hs.reload's lifecycle so products can clean up.
require("hs.ipc")

-- Make sibling product folders requireable as top-level modules
-- (e.g. spaces/init.lua becomes require("spaces")).
package.path = hs.configdir .. "/?/init.lua;"
            .. hs.configdir .. "/?.lua;"
            .. package.path

-- Per-product require root: a product's own modules use bare paths
-- (require("core.foo"), require("ui.foo")). Add each product's folder
-- to package.path so its internal requires resolve.
local productNames = require("products")
for _, name in ipairs(productNames) do
  package.path = hs.configdir .. "/" .. name .. "/?.lua;"
              .. hs.configdir .. "/" .. name .. "/?/init.lua;"
              .. package.path
end

local loaded = {}
for _, name in ipairs(productNames) do
  local ok, mod = pcall(require, name)
  if ok and mod and type(mod.start) == "function" then
    mod.start()
    table.insert(loaded, mod)
  else
    print("[host] failed to load product '" .. name .. "': " .. tostring(mod))
  end
end

-- Stop all products on reload.
hs.shutdownCallback = function()
  for _, mod in ipairs(loaded) do
    if type(mod.stop) == "function" then pcall(mod.stop) end
  end
end
