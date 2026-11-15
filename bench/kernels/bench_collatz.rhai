// bench_collatz.rhai - total Collatz steps for n=1..1,000,000
fn collatz_steps(n) {
    let steps = 0;
    while n != 1 {
        n = if n % 2 == 0 { n / 2 } else { n * 3 + 1 };
        steps += 1;
    }
    steps
}

let N = 1000000;
let t0 = timestamp();
let total = 0;
for i in 1..=N {
    total += collatz_steps(i);
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
