// Count lines and bytes, one line at a time, through the standard readline
// interface. See bench_readlines.c for the result fold.
const fs = require("fs");
const readline = require("readline");

const t0 = process.hrtime.bigint();
let lines = 0, total = 0;
const rl = readline.createInterface({
    input: fs.createReadStream("io_input.txt"),
    crlfDelay: Infinity,
});
rl.on("line", (l) => { lines++; total += l.length + 1; });
rl.on("close", () => {
    const ms = Number(process.hrtime.bigint() - t0) / 1e6;
    console.log("result:", lines * 100000000 + total);
    console.log("elapsed:", Math.round(ms));
});
