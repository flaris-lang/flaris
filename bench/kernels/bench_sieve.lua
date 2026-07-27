-- bench_sieve.lua - Sieve of Eratosthenes, N=10,000,000
local function sieve(N)
    local flags = {}
    for i = 0, N do flags[i] = 1 end
    flags[0] = 0; flags[1] = 0
    local pMax = math.floor(math.sqrt(N))
    for p = 2, pMax do
        if flags[p] == 1 then
            local i = p * p
            while i <= N do
                flags[i] = 0
                i = i + p
            end
        end
    end
    local count = 0
    for i = 2, N do
        if flags[i] == 1 then count = count + 1 end
    end
    return count
end

local N = 10000000
local t0 = os.clock()
local count = sieve(N)
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. count)
print("elapsed: " .. elapsed .. " ms")
