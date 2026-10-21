-- bench_fannkuch.lua - fannkuch-redux over every permutation of 10 elements.
-- Dominated by small integer-array reads, writes and swaps in short inner loops.
-- Algorithm from The Computer Language Benchmarks Game: permutations in its
-- rotation order, checksum = sum of the flip counts with the sign alternating per
-- permutation index. result = checksum * 1000 + max flips.
local function fannkuch(n)
    local perm1, perm, count = {}, {}, {}
    for i = 0, n - 1 do perm1[i] = i; perm[i] = 0; count[i] = 0 end
    local max_flips = 0
    local checksum = 0
    local sign = 1
    local r = n
    while true do
        while r ~= 1 do
            count[r - 1] = r
            r = r - 1
        end
        for i = 0, n - 1 do perm[i] = perm1[i] end
        local flips = 0
        local k = perm[0]
        while k ~= 0 do
            local i, j = 0, k
            while i < j do
                perm[i], perm[j] = perm[j], perm[i]
                i = i + 1
                j = j - 1
            end
            flips = flips + 1
            k = perm[0]
        end
        if flips > max_flips then max_flips = flips end
        checksum = checksum + sign * flips
        sign = -sign
        -- Next permutation: rotate the first r + 1 elements left by one; when that
        -- brings a prefix back to its start, move on to a longer prefix.
        while true do
            if r == n then return checksum * 1000 + max_flips end
            local first = perm1[0]
            for i = 0, r - 1 do perm1[i] = perm1[i + 1] end
            perm1[r] = first
            count[r] = count[r] - 1
            if count[r] > 0 then break end
            r = r + 1
        end
    end
end

local n = 10
local t0 = os.clock()
local result = fannkuch(n)
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. result)
print("elapsed: " .. elapsed .. " ms")
