function bottomUp(d) { if (d <= 0) return [null, null]; return [bottomUp(d-1), bottomUp(d-1)]; }
function check(n) { if (n[0] === null) return 1; return 1 + check(n[0]) + check(n[1]); }
const maxDepth = 16;
const t0 = Date.now();
let total = 0;
for (let d = 4; d <= maxDepth; d += 2) {
    const iters = 1 << (maxDepth - d + 4);
    for (let i = 0; i < iters; i++) total += check(bottomUp(d));
}
console.log("result: " + total);
console.log("elapsed: " + (Date.now() - t0) + " ms");
