// bench_json_node.js - parse an 18 MB JSON array, ITERS times, summing value.
const fs = require("fs");
const text = fs.readFileSync("bench_data.json", "utf8");
const ITERS = 5;
const t0 = Date.now();
let total = 0;
for (let k = 0; k < ITERS; k++) {
    const arr = JSON.parse(text);
    for (let i = 0; i < arr.length; i++) total += arr[i].value;
}
const elapsed = Date.now() - t0;
console.log("result: " + total);
console.log("elapsed: " + elapsed + " ms");
