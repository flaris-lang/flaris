-- bench_dict.lua - string-keyed map build + lookup
local n = 200000
local keys = {}
for i = 0, n-1 do keys[i] = "key" .. i end
local t0 = os.clock()
local m = {}
for i = 0, n-1 do m[keys[i]] = i end
local total = 0
for _ = 1, 3 do
    for i = 0, n-1 do total = total + m[keys[i]] end
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
