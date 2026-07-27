// bench_regex_node.js - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
const fs = require("fs");
const text = fs.readFileSync("bench_corpus.txt", "utf8");
const SCANS = 5;
const re = /\b\d{4}-\d{2}-\d{2}\b/g;
const t0 = Date.now();
let total = 0;
for (let k = 0; k < SCANS; k++) {
    const m = text.match(re);
    total += m ? m.length : 0;
}
const elapsed = Date.now() - t0;
console.log("result: " + total);
console.log("elapsed: " + elapsed + " ms");
