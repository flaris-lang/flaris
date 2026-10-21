// bench_spectralnorm.js - spectral norm of the infinite matrix A, size 800.
// Dominated by float multiply-adds in nested loops over float arrays, and the
// integer arithmetic that computes each element of A.
// Algorithm from The Computer Language Benchmarks Game, 10 power iterations of
// u = AtA v. result = round(sqrt(vBv / vv) * 1e9).
function evalA(i, j) {
    return 1.0 / ((i + j) * (i + j + 1) / 2 + i + 1);
}

function mulAv(n, v, av) {
    for (let i = 0; i < n; i++) {
        let s = 0.0;
        for (let j = 0; j < n; j++) s += evalA(i, j) * v[j];
        av[i] = s;
    }
}

function mulAtv(n, v, atv) {
    for (let i = 0; i < n; i++) {
        let s = 0.0;
        for (let j = 0; j < n; j++) s += evalA(j, i) * v[j];
        atv[i] = s;
    }
}

function mulAtAv(n, v, atav, tmp) {
    mulAv(n, v, tmp);
    mulAtv(n, tmp, atav);
}

function spectralNorm(n) {
    const u = new Array(n).fill(1.0);
    const v = new Array(n).fill(0.0);
    const tmp = new Array(n).fill(0.0);
    for (let k = 0; k < 10; k++) {
        mulAtAv(n, u, v, tmp);
        mulAtAv(n, v, u, tmp);
    }
    let vBv = 0.0, vv = 0.0;
    for (let i = 0; i < n; i++) {
        vBv += u[i] * v[i];
        vv += v[i] * v[i];
    }
    return Math.sqrt(vBv / vv);
}

const n = 800;
const t0 = Date.now();
const norm = spectralNorm(n);
console.log("result: " + Math.round(norm * 1e9));
console.log("elapsed: " + (Date.now() - t0) + " ms");
