// bench_collatz_duk.js - total Collatz steps for n=1..1,000,000 (Duktape; ES5.1)
function collatzSteps(n) {
    var steps = 0;
    while (n !== 1) {
        n = (n % 2 === 0) ? n / 2 : n * 3 + 1;
        steps++;
    }
    return steps;
}

var N = 1000000;
var t0 = Date.now();
var total = 0;
for (var i = 1; i <= N; i++) total += collatzSteps(i);
var elapsed = Date.now() - t0;
print("result: " + total);
print("elapsed: " + elapsed + " ms");
