const n = 120000;
const base = new Array(n);
let seed = 12345;
for (let i = 0; i < n; i++) {
    seed = (seed * 48271) % 2147483647;
    base[i] = seed % 1000000;
}
const t0 = Date.now();
let total = 0;
for (let p = 0; p < 6; p++) {
    const arr = base.slice();
    arr.sort((a, b) => a - b);
    total += arr[0] + arr[n - 1];
}
console.log("result: " + total);
console.log("elapsed: " + (Date.now() - t0) + " ms");
