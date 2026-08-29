// bench_fib.rs - recursive Fibonacci, n=38
use std::time::Instant;

fn fib(n: i32) -> i64 {
    if n <= 1 {
        return n as i64;
    }
    fib(n - 1) + fib(n - 2)
}

fn main() {
    let n = 38;
    let t0 = Instant::now();
    let result = fib(n);
    let elapsed = t0.elapsed().as_millis();
    println!("result: {}", result);
    println!("elapsed: {} ms", elapsed);
}
