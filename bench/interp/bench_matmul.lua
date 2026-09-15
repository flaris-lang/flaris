-- bench_matmul.lua - 220x220 integer matrix multiply
local n = 220
local a, b = {}, {}
for i = 0, n-1 do
    local ra, rb = {}, {}
    for j = 0, n-1 do ra[j] = (i + j) % 7; rb[j] = (i * j) % 5 end
    a[i] = ra; b[i] = rb
end
local t0 = os.clock()
local total = 0
for i = 0, n-1 do
    local ai = a[i]
    for j = 0, n-1 do
        local s = 0
        for k = 0, n-1 do s = s + ai[k] * b[k][j] end
        total = total + s
    end
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
