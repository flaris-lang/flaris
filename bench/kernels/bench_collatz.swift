// bench_collatz.swift - total Collatz steps for n=1..1,000,000
func collatzSteps(_ start: Int) -> Int {
    var n = start
    var steps = 0
    while n != 1 {
        n = n & 1 != 0 ? n * 3 + 1 : n >> 1
        steps += 1
    }
    return steps
}

let n = 1_000_000
let clock = ContinuousClock()
let t0 = clock.now
var total = 0
for i in 1...n {
    total += collatzSteps(i)
}
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(total)")
print("elapsed: \(ms) ms")
