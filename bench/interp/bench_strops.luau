-- bench_strops.lua - split / search / join
local line = "alpha,beta,gamma,delta,epsilon,zeta,eta,theta"
local function split(s, sep)
    local out, i = {}, 0
    for piece in string.gmatch(s, "([^" .. sep .. "]+)") do i = i + 1; out[i] = piece end
    return out, i
end
local n = 120000
local t0 = os.clock()
local total = 0
for _ = 1, n do
    local parts, cnt = split(line, ",")
    total = total + cnt
    if string.find(line, "delta", 1, true) then total = total + 1 end
    local joined = table.concat(parts, "|")
    total = total + #joined
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
