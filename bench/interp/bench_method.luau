-- bench_method.lua - method dispatch via metatable
local Vec = {}
Vec.__index = Vec
function Vec.new(x, y) return setmetatable({x = x, y = y}, Vec) end
function Vec:AddX(d) self.x = self.x + d end
function Vec:Dot() return self.x * self.y end
local v = Vec.new(1, 3)
local n = 6000000
local t0 = os.clock()
local total = 0
for _ = 1, n do
    v:AddX(1)
    total = total + v:Dot()
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. total)
print("elapsed: " .. elapsed .. " ms")
