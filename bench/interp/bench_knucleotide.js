// bench_knucleotide.js - k-nucleotide frequencies of a 2,000,000-base DNA string:
// every substring of length 1, 2, 3, 4, 6, 12 and 18 counted in a string-keyed
// map, then five fixed sequences looked up. Dominated by substring creation,
// string hashing and map update. Algorithm from The Computer Language
// Benchmarks Game; the input comes from an integer generator so that every
// language builds the same string.
// result = (r * 31 + v) % 1000000007 folded over the number of distinct keys
// for each length and the count of each fixed sequence.
const MOD = 1000000007;

function dna(n) {
    const bases = "ACGT";
    const parts = [];
    let seed = 42;
    for (let i = 0; i < n; i++) {
        seed = (seed * 3877 + 29573) % 139968;
        parts.push(bases[Math.floor(seed * 4 / 139968)]);
    }
    return parts.join("");
}

function count(seq, k) {
    const counts = new Map();
    for (let i = 0; i <= seq.length - k; i++) {
        const key = seq.substring(i, i + k);
        counts.set(key, (counts.get(key) || 0) + 1);
    }
    return counts;
}

const seq = dna(2000000);
const queries = ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"];
const t0 = Date.now();
let r = 0;
r = (r * 31 + count(seq, 1).size) % MOD;
r = (r * 31 + count(seq, 2).size) % MOD;
for (const q of queries) {
    const counts = count(seq, q.length);
    r = (r * 31 + counts.size) % MOD;
    r = (r * 31 + (counts.get(q) || 0)) % MOD;
}
const elapsed = Date.now() - t0;
console.log("result: " + r);
console.log("elapsed: " + elapsed + " ms");
