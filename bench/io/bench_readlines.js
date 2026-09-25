// Count lines and bytes, one line at a time, using this engine's own file API.
// See bench_readlines.c for the result fold.
import * as std from "std";

const t0 = Date.now();
let lines = 0, total = 0;
const f = std.open("io_input.txt", "rb");
let line;
while ((line = f.getline()) !== null) {
    lines++;
    total += line.length + 1;
}
f.close();
const ms = Date.now() - t0;
// console.log, not printf: the %d conversion here is 32-bit and would truncate
// the folded result.
console.log("result: " + (lines * 100000000 + total));
console.log("elapsed: " + ms);
