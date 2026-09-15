// bench_collatz.wren - total Collatz steps for n=1..1,000,000
var collatzSteps = Fn.new { |start|
  var n = start
  var steps = 0
  while (n != 1) {
    n = (n % 2 == 0) ? (n / 2).floor : n * 3 + 1
    steps = steps + 1
  }
  return steps
}

var N = 1000000
var t0 = System.clock
var total = 0
var i = 1
while (i <= N) {
  total = total + collatzSteps.call(i)
  i = i + 1
}
var elapsed = ((System.clock - t0) * 1000).floor
System.print("result: %(total)")
System.print("elapsed: %(elapsed) ms")
