// bench_fib.js - recursive Fibonacci, n=38 (qjs)
function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

const n = 38;
const t0 = Date.now();
const result = fib(n);
const elapsed = Date.now() - t0;
print("result: " + result);
print("elapsed: " + elapsed + " ms");
