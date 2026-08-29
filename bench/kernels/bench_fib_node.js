// bench_fib_node.js - recursive Fibonacci, n=38
function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

const n = 38;
const t0 = Date.now();
const result = fib(n);
const elapsed = Date.now() - t0;
console.log("result: " + result);
console.log("elapsed: " + elapsed + " ms");
