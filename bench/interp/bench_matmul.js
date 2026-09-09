const n = 220;
const a = [], b = [];
for (let i = 0; i < n; i++) {
    const ra = new Array(n), rb = new Array(n);
    for (let j = 0; j < n; j++) { ra[j] = (i + j) % 7; rb[j] = (i * j) % 5; }
    a.push(ra); b.push(rb);
}
const t0 = Date.now();
let total = 0;
for (let i = 0; i < n; i++) {
    const ai = a[i];
    for (let j = 0; j < n; j++) {
        let s = 0;
        for (let k = 0; k < n; k++) s += ai[k] * b[k][j];
        total += s;
    }
}
console.log("result: " + total);
console.log("elapsed: " + (Date.now() - t0) + " ms");
