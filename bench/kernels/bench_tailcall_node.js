// bench_tailcall_node.js - self-recursive tail call, depth 2,000,000
//
// V8 never implemented the ES2015 proper-tail-calls spec, so this is
// expected to throw "Maximum call stack size exceeded" well short of
// completing - see bench/README.md's tail-call section.
function tailsum(n, acc) {
    if (n === 0) return acc;
    return tailsum(n - 1, acc + n);
}

const n = 2000000;
const t0 = Date.now();
const result = tailsum(n, 0);
const elapsed = Date.now() - t0;
console.log("result: " + result);
console.log("elapsed: " + elapsed + " ms");
