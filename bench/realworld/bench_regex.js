// bench_regex.js (qjs) - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
import * as std from "std";
var text = std.loadFile("bench_corpus.txt");
var SCANS = 5;
var re = /\b\d{4}-\d{2}-\d{2}\b/g;
var t0 = Date.now();
var total = 0;
for (var k = 0; k < SCANS; k++) {
    var m = text.match(re);
    total += m ? m.length : 0;
}
var elapsed = Date.now() - t0;
print("result: " + total);
print("elapsed: " + elapsed + " ms");
