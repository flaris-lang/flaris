// bench_knucleotide.rhai - k-nucleotide frequencies of a 2,000,000-base DNA string:
// every substring of length 1, 2, 3, 4, 6, 12 and 18 counted in a string-keyed
// map, then five fixed sequences looked up. Dominated by substring creation,
// string hashing and map update. Algorithm from The Computer Language
// Benchmarks Game; the input comes from an integer generator so that every
// language builds the same string.
// result = (r * 31 + v) % 1000000007 folded over the number of distinct keys
// for each length and the count of each fixed sequence.
// The sequence is a blob of ASCII bytes: Rhai strings index by character, so
// sub_string walks the string from its start and a window over 2M bases would be
// quadratic. extract(i, k).as_string() makes each key from k bytes.
const MOD = 1000000007;

fn dna(n) {
    let bases = "ACGT".to_blob();
    let seq = blob();
    let seed = 42;
    for i in 0..n {
        seed = (seed * 3877 + 29573) % 139968;
        seq.push(bases[seed * 4 / 139968]);
    }
    seq
}

// Called on the sequence, so the 2 MB blob is not copied per call.
fn count(k) {
    let counts = #{};
    for i in 0..=(this.len() - k) {
        let key = this.extract(i, k).as_string();
        counts[key] = (counts[key] ?? 0) + 1;
    }
    counts
}

let seq = dna(2000000);
let queries = ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"];
let t0 = timestamp();
let r = 0;
r = (r * 31 + seq.count(1).len()) % MOD;
r = (r * 31 + seq.count(2).len()) % MOD;
for q in queries {
    let counts = seq.count(q.len());
    r = (r * 31 + counts.len()) % MOD;
    r = (r * 31 + (counts[q] ?? 0)) % MOD;
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + r);
print("elapsed: " + elapsed + " ms");
