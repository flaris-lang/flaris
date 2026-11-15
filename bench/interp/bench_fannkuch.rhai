// bench_fannkuch.rhai - fannkuch-redux over every permutation of 10 elements.
// Dominated by small integer-array reads, writes and swaps in short inner loops.
// Algorithm from The Computer Language Benchmarks Game: permutations in its
// rotation order, checksum = sum of the flip counts with the sign alternating per
// permutation index. result = checksum * 1000 + max flips.
fn fannkuch(n) {
    let perm1 = [];
    let perm = [];
    let count = [];
    for i in 0..n { perm1.push(i); perm.push(0); count.push(0); }
    let max_flips = 0;
    let checksum = 0;
    let sign = 1;
    let r = n;
    loop {
        while r != 1 {
            count[r - 1] = r;
            r -= 1;
        }
        for i in 0..n { perm[i] = perm1[i]; }
        let flips = 0;
        let k = perm[0];
        while k != 0 {
            let i = 0;
            let j = k;
            while i < j {
                let t = perm[i];
                perm[i] = perm[j];
                perm[j] = t;
                i += 1;
                j -= 1;
            }
            flips += 1;
            k = perm[0];
        }
        if flips > max_flips { max_flips = flips; }
        checksum += sign * flips;
        sign = -sign;
        // Next permutation: rotate the first r + 1 elements left by one; when that
        // brings a prefix back to its start, move on to a longer prefix.
        loop {
            if r == n { return checksum * 1000 + max_flips; }
            let first = perm1[0];
            for i in 0..r { perm1[i] = perm1[i + 1]; }
            perm1[r] = first;
            count[r] -= 1;
            if count[r] > 0 { break; }
            r += 1;
        }
    }
}

let n = 10;
let t0 = timestamp();
let result = fannkuch(n);
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + result);
print("elapsed: " + elapsed + " ms");
