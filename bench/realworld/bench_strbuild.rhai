// bench_strbuild.rhai - build a large string by naive s += piece, N times.
// Rhai appends in place when the string is not shared, so this is linear.
let N = 1000000;
let t0 = timestamp();
let s = "";
for i in 0..N { s += "item_" + i + ";"; }
let result = s.len();
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + result);
print("elapsed: " + elapsed + " ms");
