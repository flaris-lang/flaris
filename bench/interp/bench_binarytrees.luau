-- bench_binarytrees.lua
local function bottom_up(d)
    if d <= 0 then return {nil, nil} end
    return {bottom_up(d - 1), bottom_up(d - 1)}
end
local function check(n)
    if n[1] == nil then return 1 end
    return 1 + check(n[1]) + check(n[2])
end
local max_depth = 16
local t0 = os.clock()
local total = 0
local d = 4
while d <= max_depth do
    local iters = math.floor(2 ^ (max_depth - d + 4))
    for _ = 1, iters do total = total + check(bottom_up(d)) end
    d = d + 2
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
