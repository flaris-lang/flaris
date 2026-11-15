// bench_matmul.rhai - 220x220 integer matrix multiply
let n = 220;
let a = [];
let b = [];
for i in 0..n {
    let ra = [];
    let rb = [];
    for j in 0..n { ra.push((i + j) % 7); rb.push((i * j) % 5); }
    a.push(ra);
    b.push(rb);
}
let t0 = timestamp();
let total = 0;
for i in 0..n {
    let ai = a[i];
    for j in 0..n {
        let s = 0;
        for k in 0..n { s += ai[k] * b[k][j]; }
        total += s;
    }
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
