// Read the whole file into memory. See bench_slurp.c for what this measures.
const fs = require("fs");
const t0 = process.hrtime.bigint();
const data = fs.readFileSync("io_input.txt");
const ms = Number(process.hrtime.bigint() - t0) / 1e6;
console.log("result: " + data.length);
console.log("elapsed: " + Math.round(ms));
