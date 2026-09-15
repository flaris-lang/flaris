// bench_fib.nut - recursive Fibonacci, n=38
function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

local t0 = clock();
local result = fib(38);
local elapsed = ((clock() - t0) * 1000).tointeger();
print("result: " + result + "\n");
print("elapsed: " + elapsed + " ms\n");
