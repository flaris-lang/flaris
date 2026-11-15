// bench_spectralnorm.rhai - spectral norm of the infinite matrix A, size 800.
// Dominated by float multiply-adds in nested loops over float arrays, and the
// integer arithmetic that computes each element of A.
// Algorithm from The Computer Language Benchmarks Game, 10 power iterations of
// u = AtA v. result = round(sqrt(vBv / vv) * 1e9).
// Arrays are values, so the output array of each product is `this`: av.mul_av(n, v)
// fills av in place.
fn eval_a(i, j) {
    1.0 / ((i + j) * (i + j + 1) / 2 + i + 1)
}

fn mul_av(n, v) {
    for i in 0..n {
        let s = 0.0;
        for j in 0..n {
            s += eval_a(i, j) * v[j];
        }
        this[i] = s;
    }
}

fn mul_atv(n, v) {
    for i in 0..n {
        let s = 0.0;
        for j in 0..n {
            s += eval_a(j, i) * v[j];
        }
        this[i] = s;
    }
}

fn mul_atav(n, v, tmp) {
    tmp.mul_av(n, v);
    this.mul_atv(n, tmp);
}

fn spectral_norm(n) {
    let u = [];
    let v = [];
    let tmp = [];
    for i in 0..n { u.push(1.0); v.push(0.0); tmp.push(0.0); }
    for k in 0..10 {
        v.mul_atav(n, u, tmp);
        u.mul_atav(n, v, tmp);
    }
    let vbv = 0.0;
    let vv = 0.0;
    for i in 0..n {
        vbv += u[i] * v[i];
        vv += v[i] * v[i];
    }
    sqrt(vbv / vv)
}

let n = 800;
let t0 = timestamp();
let norm = spectral_norm(n);
let result = (norm * 1e9 + 0.5).floor().to_int();
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + result);
print("elapsed: " + elapsed + " ms");
