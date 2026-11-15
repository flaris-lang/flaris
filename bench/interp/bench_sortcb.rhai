// bench_sortcb.rhai - array sort with a script comparator
let n = 120000;
let base = [];
let seed = 12345;
for i in 0..n {
    seed = (seed * 48271) % 2147483647;
    base.push(seed % 1000000);
}
let t0 = timestamp();
let total = 0;
for p in 0..6 {
    let arr = base;                 // arrays are values: this copies base
    arr.sort(|a, b| a - b);
    total += arr[0] + arr[n - 1];
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
