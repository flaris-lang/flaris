-- bench_spectralnorm.lua - spectral norm of the infinite matrix A, size 800.
-- Dominated by float multiply-adds in nested loops over float arrays, and the
-- integer arithmetic that computes each element of A.
-- Algorithm from The Computer Language Benchmarks Game, 10 power iterations of
-- u = AtA v. result = round(sqrt(vBv / vv) * 1e9).
local function eval_a(i, j)
    return 1.0 / ((i + j) * (i + j + 1) / 2 + i + 1)
end

local function mul_av(n, v, av)
    for i = 0, n - 1 do
        local s = 0.0
        for j = 0, n - 1 do
            s = s + eval_a(i, j) * v[j]
        end
        av[i] = s
    end
end

local function mul_atv(n, v, atv)
    for i = 0, n - 1 do
        local s = 0.0
        for j = 0, n - 1 do
            s = s + eval_a(j, i) * v[j]
        end
        atv[i] = s
    end
end

local function mul_atav(n, v, atav, tmp)
    mul_av(n, v, tmp)
    mul_atv(n, tmp, atav)
end

local function spectral_norm(n)
    local u, v, tmp = {}, {}, {}
    for i = 0, n - 1 do u[i] = 1.0; v[i] = 0.0; tmp[i] = 0.0 end
    for _ = 1, 10 do
        mul_atav(n, u, v, tmp)
        mul_atav(n, v, u, tmp)
    end
    local vbv, vv = 0.0, 0.0
    for i = 0, n - 1 do
        vbv = vbv + u[i] * v[i]
        vv = vv + v[i] * v[i]
    end
    return math.sqrt(vbv / vv)
end

local n = 800
local t0 = os.clock()
local norm = spectral_norm(n)
local result = math.floor(norm * 1e9 + 0.5)
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. result)
print("elapsed: " .. elapsed .. " ms")
