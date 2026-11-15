// bench_fib.rhai - recursive Fibonacci, n=38
fn fib(n) {
    if n <= 1 { return n; }
    fib(n - 1) + fib(n - 2)
}

let n = 38;
let t0 = timestamp();
let result = fib(n);
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + result);
print("elapsed: " + elapsed + " ms");
