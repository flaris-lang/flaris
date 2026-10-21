-- bench_knucleotide.lua - k-nucleotide frequencies of a 2,000,000-base DNA string:
-- every substring of length 1, 2, 3, 4, 6, 12 and 18 counted in a string-keyed
-- map, then five fixed sequences looked up. Dominated by substring creation,
-- string hashing and map update. Algorithm from The Computer Language
-- Benchmarks Game; the input comes from an integer generator so that every
-- language builds the same string.
-- result = (r * 31 + v) % 1000000007 folded over the number of distinct keys
-- for each length and the count of each fixed sequence.
local MOD = 1000000007

local function dna(n)
    local bases = {"A", "C", "G", "T"}
    local parts = {}
    local seed = 42
    for i = 1, n do
        seed = (seed * 3877 + 29573) % 139968
        parts[i] = bases[math.floor(seed * 4 / 139968) + 1]
    end
    return table.concat(parts)
end

local function count(seq, k)
    local counts = {}
    for i = 1, #seq - k + 1 do
        local key = string.sub(seq, i, i + k - 1)
        counts[key] = (counts[key] or 0) + 1
    end
    return counts
end

local function size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local seq = dna(2000000)
local queries = {"GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"}
local t0 = os.clock()
local r = 0
r = (r * 31 + size(count(seq, 1))) % MOD
r = (r * 31 + size(count(seq, 2))) % MOD
for _, q in ipairs(queries) do
    local counts = count(seq, #q)
    r = (r * 31 + size(counts)) % MOD
    r = (r * 31 + (counts[q] or 0)) % MOD
end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. r)
print("elapsed: " .. elapsed .. " ms")
