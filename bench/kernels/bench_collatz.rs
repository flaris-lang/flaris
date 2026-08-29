// bench_collatz.rs - total Collatz steps for n=1..1,000,000
use std::time::Instant;

fn collatz_steps(mut n: i64) -> i64 {
    let mut steps = 0i64;
    while n != 1 {
        n = if n & 1 != 0 { n * 3 + 1 } else { n >> 1 };
        steps += 1;
    }
    steps
}

fn main() {
    let n = 1_000_000i64;
    let t0 = Instant::now();
    let mut total = 0i64;
    for i in 1..=n {
        total += collatz_steps(i);
    }
    let elapsed = t0.elapsed().as_millis();
    println!("result: {}", total);
    println!("elapsed: {} ms", elapsed);
}
