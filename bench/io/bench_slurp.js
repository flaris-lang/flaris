// Read the whole file into memory. See bench_slurp.c for what this measures.
import * as std from "std";
const t0 = Date.now();
const data = std.loadFile("io_input.txt");
const ms = Date.now() - t0;
console.log("result: " + data.length);
console.log("elapsed: " + ms);
