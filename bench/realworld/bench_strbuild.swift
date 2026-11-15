// bench_strbuild.swift - build a large string, N times. Swift strings are
// mutable values with spare capacity, so += is amortised linear. result is the
// byte length.
let n = 1_000_000
let clock = ContinuousClock()
let t0 = clock.now
var s = ""
for i in 0..<n {
    s += "item_"
    s += String(i)
    s += ";"
}
let result = s.utf8.count
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(result)")
print("elapsed: \(ms) ms")
