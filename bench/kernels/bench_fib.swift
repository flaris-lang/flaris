// bench_fib.swift - recursive Fibonacci, n=38
func fib(_ n: Int) -> Int {
    if n <= 1 { return n }
    return fib(n - 1) + fib(n - 2)
}

let n = 38
let clock = ContinuousClock()
let t0 = clock.now
let result = fib(n)
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(result)")
print("elapsed: \(ms) ms")
