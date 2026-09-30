// Write a million formatted lines. See bench_write.c for what this measures.
import * as std from "std";
import * as os from "os";

const LINES = 1000000;
const t0 = Date.now();
const f = std.open("io_out_qjs.txt", "wb");
for (let i = 0; i < LINES; i++) f.puts(i + " payload " + ((i * 7) % 9973) + "\n");
f.close();
const ms = Date.now() - t0;

const st = os.stat("io_out_qjs.txt")[0];
os.remove("io_out_qjs.txt");
console.log("result: " + st.size);
console.log("elapsed: " + ms);
