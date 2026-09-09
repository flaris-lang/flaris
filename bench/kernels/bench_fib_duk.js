// bench_fib_duk.js - recursive Fibonacci, n=38 (Duktape; ES5.1, no let/const)
function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

var n = 38;
var t0 = Date.now();
var result = fib(n);
var elapsed = Date.now() - t0;
print("result: " + result);
print("elapsed: " + elapsed + " ms");
