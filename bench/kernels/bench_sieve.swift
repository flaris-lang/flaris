// bench_sieve.swift - Sieve of Eratosthenes, N=10,000,000
func sieve(_ n: Int) -> Int {
    var flags = [UInt8](repeating: 1, count: n + 1)
    flags[0] = 0
    flags[1] = 0
    var p = 2
    while p * p <= n {
        if flags[p] != 0 {
            for i in stride(from: p * p, through: n, by: p) {
                flags[i] = 0
            }
        }
        p += 1
    }
    var count = 0
    for i in 2...n where flags[i] != 0 {
        count += 1
    }
    return count
}

let n = 10_000_000
let clock = ContinuousClock()
let t0 = clock.now
let count = sieve(n)
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(count)")
print("elapsed: \(ms) ms")
