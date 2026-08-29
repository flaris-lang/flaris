// bench_sieve.rs - Sieve of Eratosthenes, N=10,000,000
use std::time::Instant;

fn sieve(n: usize) -> i32 {
    let mut flags = vec![1u8; n + 1];
    flags[0] = 0;
    flags[1] = 0;
    let mut p = 2usize;
    while p * p <= n {
        if flags[p] != 0 {
            let mut i = p * p;
            while i <= n {
                flags[i] = 0;
                i += p;
            }
        }
        p += 1;
    }
    let mut count = 0;
    for i in 2..=n {
        if flags[i] != 0 {
            count += 1;
        }
    }
    count
}

fn main() {
    let n = 10_000_000usize;
    let t0 = Instant::now();
    let count = sieve(n);
    let elapsed = t0.elapsed().as_millis();
    println!("result: {}", count);
    println!("elapsed: {} ms", elapsed);
}
