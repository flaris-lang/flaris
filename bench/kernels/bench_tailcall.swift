// bench_tailcall.swift - self-recursive tail call, depth 2,000,000
func tailsum(_ n: Int, _ acc: Int) -> Int {
    if n == 0 { return acc }
    return tailsum(n - 1, acc + n)
}

let n = 2_000_000
let clock = ContinuousClock()
let t0 = clock.now
let result = tailsum(n, 0)
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(result)")
print("elapsed: \(ms) ms")
