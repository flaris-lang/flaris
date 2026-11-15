// bench_sieve.rhai - Sieve of Eratosthenes, N=10,000,000
fn sieve(N) {
    let flags = blob(N + 1, 1);
    flags[0] = 0; flags[1] = 0;
    let pMax = sqrt(N.to_float()).to_int();
    for p in 2..=pMax {
        if flags[p] == 1 {
            let i = p * p;
            while i <= N {
                flags[i] = 0;
                i += p;
            }
        }
    }
    let count = 0;
    for i in 2..=N {
        if flags[i] == 1 { count += 1; }
    }
    count
}

let N = 10000000;
let t0 = timestamp();
let count = sieve(N);
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + count);
print("elapsed: " + elapsed + " ms");
