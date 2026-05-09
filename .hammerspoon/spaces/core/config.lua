-- Single source of truth for product-level constants. Tunables live here so
-- they can be changed in one place without code reading.
return {
  brand = {
    name = "Spaces",
    version = "1.0.0",
    glyph = "square.stack.3d.up.fill",
  },
  paths = {
    data = hs.configdir .. "/workspace-notes.json",
    profiles = hs.configdir .. "/space-profiles",
  },
  poll = {
    foregroundSec = 2,
    backgroundSec = 10,
  },
  alert = {
    textColor = { hex = "#e6e6e6" },
    fillColor = { red = 0, green = 0, blue = 0, alpha = 0.78 },
    radius = 6,
    strokeWidth = 0,
  },
  log = {
    level = "info",
  },
}
