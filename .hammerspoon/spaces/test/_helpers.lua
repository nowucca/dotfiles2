-- Shared test helpers. require()'d by every test_*.lua. State is shared because
-- require() caches modules.
local M = { count = 0, failures = 0 }

local function fail(msg)
  M.failures = M.failures + 1
  print("  FAIL: " .. msg)
end

function M.assert_eq(actual, expected, msg)
  M.count = M.count + 1
  if actual ~= expected then
    fail((msg or "assert_eq") .. " — expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

function M.assert_true(cond, msg)
  M.count = M.count + 1
  if not cond then fail((msg or "assert_true") .. " — expected true") end
end

function M.assert_nil(value, msg)
  M.count = M.count + 1
  if value ~= nil then fail((msg or "assert_nil") .. " — expected nil, got " .. tostring(value)) end
end

function M.assert_table_eq(actual, expected, msg)
  M.count = M.count + 1
  local function eq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not eq(v, b[k]) then return false end end
    for k, _ in pairs(b) do if a[k] == nil then return false end end
    return true
  end
  if not eq(actual, expected) then
    fail((msg or "assert_table_eq") .. " — tables differ")
  end
end

function M.section(name) print("== " .. name .. " ==") end
function M.summary()
  print(string.format("\n%d tests, %d failures", M.count, M.failures))
  return M.failures == 0
end

return M
