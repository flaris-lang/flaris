// Write a million formatted lines. See bench_write.c for what this measures.
//
// A write stream with backpressure honoured, which is how Node is meant to be
// used for this: ignoring the return value of write() would queue the whole
// million lines in memory and measure allocation rather than writing. The clock
// stops in the end callback, once the bytes are actually out.
const fs = require("fs");
const LINES = 1000000;

const t0 = process.hrtime.bigint();
const out = fs.createWriteStream("io_out_node.txt");

function pump(i) {
    while (i < LINES) {
        const ok = out.write(i + " payload " + ((i * 7) % 9973) + "\n");
        i++;
        if (!ok) { out.once("drain", () => pump(i)); return; }
    }
    out.end(() => {
        const ms = Number(process.hrtime.bigint() - t0) / 1e6;
        const size = fs.statSync("io_out_node.txt").size;
        fs.unlinkSync("io_out_node.txt");
        console.log("result: " + size);
        console.log("elapsed: " + Math.round(ms));
    });
}
pump(0);
