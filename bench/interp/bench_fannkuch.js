// bench_fannkuch.js - fannkuch-redux over every permutation of 10 elements.
// Dominated by small integer-array reads, writes and swaps in short inner loops.
// Algorithm from The Computer Language Benchmarks Game: permutations in its
// rotation order, checksum = sum of the flip counts with the sign alternating per
// permutation index. result = checksum * 1000 + max flips.
function fannkuch(n) {
    const perm1 = new Array(n), perm = new Array(n).fill(0), count = new Array(n).fill(0);
    for (let i = 0; i < n; i++) perm1[i] = i;
    let maxFlips = 0;
    let checksum = 0;
    let sign = 1;
    let r = n;
    while (true) {
        while (r !== 1) {
            count[r - 1] = r;
            r--;
        }
        for (let i = 0; i < n; i++) perm[i] = perm1[i];
        let flips = 0;
        let k = perm[0];
        while (k !== 0) {
            let i = 0, j = k;
            while (i < j) {
                const t = perm[i];
                perm[i] = perm[j];
                perm[j] = t;
                i++;
                j--;
            }
            flips++;
            k = perm[0];
        }
        if (flips > maxFlips) maxFlips = flips;
        checksum += sign * flips;
        sign = -sign;
        // Next permutation: rotate the first r + 1 elements left by one; when that
        // brings a prefix back to its start, move on to a longer prefix.
        while (true) {
            if (r === n) return checksum * 1000 + maxFlips;
            const first = perm1[0];
            for (let i = 0; i < r; i++) perm1[i] = perm1[i + 1];
            perm1[r] = first;
            count[r]--;
            if (count[r] > 0) break;
            r++;
        }
    }
}

const n = 10;
const t0 = Date.now();
const result = fannkuch(n);
console.log("result: " + result);
console.log("elapsed: " + (Date.now() - t0) + " ms");
