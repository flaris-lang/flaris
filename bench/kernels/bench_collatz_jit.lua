-- bench_collatz_jit.lua - bench_collatz.lua for LuaJIT: the 5.3 integer-divide
-- operator is replaced by plain division (exact for even doubles).
local function collatz_steps(n)
    local steps = 0
    while n ~= 1 do
        n = (n % 2 == 0) and (n / 2) or (n * 3 + 1)
        steps = steps + 1
    end
    return steps
end

local N = 1000000
local t0 = os.clock()
local total = 0
for i = 1, N do
    total = total + collatz_steps(i)
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
