// bench_tailcall.js - self-recursive tail call, depth 2,000,000 (qjs)
function tailsum(n, acc) {
    if (n === 0) return acc;
    return tailsum(n - 1, acc + n);
}

const n = 2000000;
const t0 = Date.now();
const result = tailsum(n, 0);
const elapsed = Date.now() - t0;
print("result: " + result);
print("elapsed: " + elapsed + " ms");
