local h = require("_helpers")
local log = require("core.log")

-- Capture print() output by replacing the logger's writer with a buffer.
local buf = {}
log._setWriter(function(line) table.insert(buf, line) end)

log.setLevel("info")
buf = {}
log.debug("noise")
h.assert_eq(#buf, 0, "debug suppressed at info level")

log.info("hello")
h.assert_eq(#buf, 1, "info emitted at info level")
h.assert_true(buf[1]:find("INFO", 1, true) ~= nil, "info line contains INFO")
h.assert_true(buf[1]:find("hello", 1, true) ~= nil, "info line contains message")

log.setLevel("debug")
buf = {}
log.debug("now visible")
h.assert_eq(#buf, 1, "debug visible at debug level")

log.setLevel("warn")
buf = {}
log.info("hidden")
log.warn("shown")
h.assert_eq(#buf, 1, "info hidden, warn shown at warn level")

-- log.try wraps pcall: returns ok, result; logs error on failure.
buf = {}
local ok, result = log.try(function() return 42 end, "happy path")
h.assert_true(ok, "happy path ok=true")
h.assert_eq(result, 42, "happy path result")
h.assert_eq(#buf, 0, "happy path no log")

ok, result = log.try(function() error("boom") end, "sad path")
h.assert_eq(ok, false, "sad path ok=false")
h.assert_true(#buf >= 1, "sad path logged at least one line")
h.assert_true(buf[#buf]:find("sad path", 1, true) ~= nil, "log line contains context")
