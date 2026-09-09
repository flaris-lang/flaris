// bench_fib.wren - recursive Fibonacci, n=38
class B {
  static fib(n) {
    if (n <= 1) return n
    return B.fib(n - 1) + B.fib(n - 2)
  }
}

var t0 = System.clock
var result = B.fib(38)
var elapsed = ((System.clock - t0) * 1000).floor
System.print("result: %(result)")
System.print("elapsed: %(elapsed) ms")
