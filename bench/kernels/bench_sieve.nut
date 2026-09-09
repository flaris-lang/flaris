// bench_sieve.nut - Sieve of Eratosthenes, N=10,000,000
function sieve(N) {
    local flags = blob(N + 1);
    for (local i = 0; i <= N; i += 1) flags[i] = 1;
    flags[0] = 0; flags[1] = 0;
    local pMax = sqrt(N).tointeger();
    for (local p = 2; p <= pMax; p += 1) {
        if (flags[p] == 1) {
            for (local i = p * p; i <= N; i += p) flags[i] = 0;
        }
    }
    local count = 0;
    for (local i = 2; i <= N; i += 1) if (flags[i] == 1) count += 1;
    return count;
}

local N = 10000000;
local t0 = clock();
local result = sieve(N);
local elapsed = ((clock() - t0) * 1000).tointeger();
print("result: " + result + "\n");
print("elapsed: " + elapsed + " ms\n");
