// bench_sieve_node.js - Sieve of Eratosthenes, N=10,000,000
function sieve(N) {
    const flags = new Uint8Array(N + 1).fill(1);
    flags[0] = 0; flags[1] = 0;
    const pMax = Math.floor(Math.sqrt(N));
    for (let p = 2; p <= pMax; p++) {
        if (flags[p]) {
            for (let i = p * p; i <= N; i += p)
                flags[i] = 0;
        }
    }
    let count = 0;
    for (let i = 2; i <= N; i++)
        if (flags[i]) count++;
    return count;
}

const N = 10000000;
const t0 = Date.now();
const count = sieve(N);
const elapsed = Date.now() - t0;
console.log("result: " + count);
console.log("elapsed: " + elapsed + " ms");
