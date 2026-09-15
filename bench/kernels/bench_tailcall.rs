// bench_tailcall.rs - self-recursive tail call, depth 2,000,000
use std::time::Instant;

fn tailsum(n: i64, acc: i64) -> i64 {
    if n == 0 {
        return acc;
    }
    tailsum(n - 1, acc + n)
}

fn main() {
    let n: i64 = 2_000_000;
    let t0 = Instant::now();
    let result = tailsum(n, 0);
    let elapsed = t0.elapsed().as_millis();
    println!("result: {}", result);
    println!("elapsed: {} ms", elapsed);
}
