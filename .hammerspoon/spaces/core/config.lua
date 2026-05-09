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
    -- Synchronous AppleScript snapshot blocks the main thread for tens to
    -- hundreds of ms when many iTerm tabs are open. Aggressive polling can
    -- make UI elements (chooser, menubar) feel unresponsive while a snapshot
    -- is in flight. Conservative defaults; tune down only if state lag is
    -- actually noticeable.
    foregroundSec = 5,
    backgroundSec = 30,
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
