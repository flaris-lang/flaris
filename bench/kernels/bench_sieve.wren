// bench_sieve.wren - Sieve of Eratosthenes, N=10,000,000
// Wren has no typed byte buffer, so this uses a List the way the Lua lane
// uses a table.
var sieve = Fn.new { |N|
  var flags = List.filled(N + 1, 1)
  flags[0] = 0
  flags[1] = 0
  var pMax = N.sqrt.floor
  var p = 2
  while (p <= pMax) {
    if (flags[p] == 1) {
      var i = p * p
      while (i <= N) {
        flags[i] = 0
        i = i + p
      }
    }
    p = p + 1
  }
  var count = 0
  var i = 2
  while (i <= N) {
    if (flags[i] == 1) count = count + 1
    i = i + 1
  }
  return count
}

var N = 10000000
var t0 = System.clock
var result = sieve.call(N)
var elapsed = ((System.clock - t0) * 1000).floor
System.print("result: %(result)")
System.print("elapsed: %(elapsed) ms")
