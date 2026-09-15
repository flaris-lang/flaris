-- see script.fls for what this is
local function sum(n)
    local s = 0
    for i = 1, n do s = s + i end
    return s
end

total = sum(1000)

function Total() return total end
function Update(n) return n + 1 end
