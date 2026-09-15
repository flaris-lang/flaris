-- bench_strbuild.lua - build a large string via table.concat (the idiomatic
-- linear builder; naive .. in a loop is O(n^2) with Lua's immutable strings).
-- Loop is 0-based so the byte length matches the other languages.
local N = 1000000
local t0 = os.clock()
local parts = {}
for i = 0, N - 1 do
    parts[i + 1] = "item_" .. i .. ";"
end
local s = table.concat(parts)
local result = #s
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. result)
print("elapsed: " .. elapsed .. " ms")
