-- bench_sortcb.lua - table.sort with a script comparator
local n = 120000
local base = {}
local seed = 12345
for i = 1, n do
    seed = (seed * 48271) % 2147483647
    base[i] = seed % 1000000
end
local t0 = os.clock()
local total = 0
for _ = 1, 6 do
    local arr = {}
    for i = 1, n do arr[i] = base[i] end
    table.sort(arr, function(a, b) return a < b end)
    total = total + arr[1] + arr[n]
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
