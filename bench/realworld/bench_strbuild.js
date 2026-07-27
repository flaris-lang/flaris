// bench_strbuild.js (qjs) - build a large string by naive s += piece, N times.
var N = 1000000;
var t0 = Date.now();
var s = "";
for (var i = 0; i < N; i++) s += "item_" + i + ";";
var result = s.length;
var elapsed = Date.now() - t0;
print("result: " + result);
print("elapsed: " + elapsed + " ms");
