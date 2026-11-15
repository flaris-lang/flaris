// bench_dict.rhai - string-keyed map build + lookup
let n = 200000;
let keys = [];
for i in 0..n { keys.push("key" + i); }
let t0 = timestamp();
let m = #{};
for i in 0..n { m[keys[i]] = i; }
let total = 0;
for p in 0..3 {
    for i in 0..n { total += m[keys[i]]; }
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
