// bench_strbuild_node.js - build a large string by naive s += piece, N times.
const N = 1000000;
const t0 = Date.now();
let s = "";
for (let i = 0; i < N; i++) s += "item_" + i + ";";
const result = s.length;
const elapsed = Date.now() - t0;
console.log("result: " + result);
console.log("elapsed: " + elapsed + " ms");
