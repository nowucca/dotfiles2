local h = require("_helpers")
local config = require("core.config")

h.assert_eq(config.brand.name, "Spaces", "brand.name")
h.assert_eq(config.brand.version, "1.0.0", "brand.version")
h.assert_eq(config.brand.glyph, "square.stack.3d.up.fill", "brand.glyph")

h.assert_true(config.paths.data:match("workspace%-notes%.json$") ~= nil, "paths.data ends with workspace-notes.json")
h.assert_true(config.paths.profiles:match("space%-profiles$") ~= nil, "paths.profiles ends with space-profiles")

h.assert_eq(config.poll.foregroundSec, 2, "poll.foregroundSec")
h.assert_eq(config.poll.backgroundSec, 10, "poll.backgroundSec")

h.assert_eq(config.log.level, "info", "log.level default")

h.assert_true(config.alert.radius == 6, "alert.radius")
h.assert_true(type(config.alert.fillColor) == "table", "alert.fillColor is a table")
