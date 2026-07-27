-- bench_fib.lua - recursive Fibonacci, n=38
local function fib(n)
    if n <= 1 then return n end
    return fib(n - 1) + fib(n - 2)
end

local n = 38
local t0 = os.clock()
local result = fib(n)
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. result)
print("elapsed: " .. elapsed .. " ms")
