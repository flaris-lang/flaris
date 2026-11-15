// bench_strops.rhai - split / search / join
// Rhai arrays have no join, so it is written here as a method.
fn join(sep) {
    let s = this[0];
    for i in 1..this.len() { s += sep; s += this[i]; }
    s
}

let line = "alpha,beta,gamma,delta,epsilon,zeta,eta,theta";
let n = 120000;
let t0 = timestamp();
let total = 0;
for i in 0..n {
    let parts = line.split(",");
    total += parts.len();
    if "delta" in line { total += 1; }
    let joined = parts.join("|");
    total += joined.len();
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
