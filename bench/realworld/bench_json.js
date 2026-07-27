// bench_json.js (qjs) - parse an 18 MB JSON array, ITERS times, summing value.
import * as std from "std";
var text = std.loadFile("bench_data.json");
var ITERS = 5;
var t0 = Date.now();
var total = 0;
for (var k = 0; k < ITERS; k++) {
    var arr = JSON.parse(text);
    for (var i = 0; i < arr.length; i++) total += arr[i].value;
}
var elapsed = Date.now() - t0;
print("result: " + total);
print("elapsed: " + elapsed + " ms");
