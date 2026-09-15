-- bench_tailcall.lua - self-recursive tail call, depth 2,000,000
-- Lua has guaranteed proper tail calls since 5.1: this never grows the call
-- stack no matter how deep n is. Shared by the lua and luajit lanes.
local function tailsum(n, acc)
    if n == 0 then return acc end
    return tailsum(n - 1, acc + n)
end

local n = 2000000
local t0 = os.clock()
local result = tailsum(n, 0)
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. result)
print("elapsed: " .. elapsed .. " ms")
