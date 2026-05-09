# Hammerspoon — features and host

## Spaces product

The Spaces product (menubar, agent state tracking, launchers, hotkeys) lives in **`~/spaces/hs-spaces/hs-spaces/main/`**. For full feature reference (hotkeys, menubar layout, state convention, console namespace, troubleshooting), see that repo's:

- `README.md` — install + hotkeys + state convention + layout
- `memory_bank/systemPatterns.md` — architecture, async AppleScript pattern, module responsibilities
- `memory_bank/techContext.md` — Hammerspoon API surface, iTerm quirks, performance targets

Edit either side of the symlink; both reflect.

## Dotfiles host (this repo)

`.hammerspoon/init.lua` is a thin host (~37 lines):

```lua
require("hs.ipc")
package.path = hs.configdir .. "/?/init.lua;" .. hs.configdir .. "/?.lua;" .. package.path

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

hs.shutdownCallback = function()
  for _, mod in ipairs(loaded) do
    if type(mod.stop) == "function" then pcall(mod.stop) end
  end
end
```

`.hammerspoon/products.lua` lists product folder names:

```lua
return { "spaces" }
```

`.hammerspoon/spaces` is an absolute symlink into `~/spaces/hs-spaces/hs-spaces/main/hammerspoon/spaces`.

## Adding a new product

1. Create the new product repo under `~/spaces/<name>/<name>/main/`.
2. Lay out `hammerspoon/<name>/init.lua` exporting `start()` and `stop()`.
3. From dotfiles: `ln -s /Users/satkinson/spaces/<name>/<name>/main/hammerspoon/<name> .hammerspoon/<name>`.
4. Add `"<name>"` to `.hammerspoon/products.lua`.
5. `./bootstrap.sh -f && hs -c "hs.reload()"`.

## Host-side troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Product not loading | Check `_G.ws.<name>` in console; if nil, look for `[host] failed to load product` line on Hammerspoon startup |
| Symlink replaced by real dir after bootstrap | bootstrap created a real dir before the symlink existed in the repo. `rm -rf ~/.hammerspoon/<name>` then bootstrap |
| Product files edited but changes don't apply | `hs.reload()` after edit. If `package.loaded` is sticky, the product's own test runner usually clears caches; reload is the host-level reset |
| Two menubar widgets | Old + new product both running. Confirm only the new is in `products.lua`; restart Hammerspoon |
