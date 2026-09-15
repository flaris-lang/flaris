// bench_sieve_duk.js - Sieve of Eratosthenes, N=10,000,000 (Duktape; ES5.1)
function sieve(N) {
    var flags = new Uint8Array(N + 1);
    for (var k = 0; k <= N; k++) flags[k] = 1;
    flags[0] = 0; flags[1] = 0;
    var pMax = Math.floor(Math.sqrt(N));
    for (var p = 2; p <= pMax; p++) {
        if (flags[p]) {
            for (var i = p * p; i <= N; i += p) flags[i] = 0;
        }
    }
    var count = 0;
    for (var i2 = 2; i2 <= N; i2++) if (flags[i2]) count++;
    return count;
}

var N = 10000000;
var t0 = Date.now();
var result = sieve(N);
var elapsed = Date.now() - t0;
print("result: " + result);
print("elapsed: " + elapsed + " ms");
