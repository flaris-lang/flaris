// bench_collatz.nut - total Collatz steps for n=1..1,000,000
function collatz_steps(n) {
    local steps = 0;
    while (n != 1) {
        n = (n % 2 == 0) ? (n / 2) : (n * 3 + 1);
        steps += 1;
    }
    return steps;
}

local N = 1000000;
local t0 = clock();
local total = 0;
for (local i = 1; i <= N; i += 1) total += collatz_steps(i);
local elapsed = ((clock() - t0) * 1000).tointeger();
print("result: " + total + "\n");
print("elapsed: " + elapsed + " ms\n");
