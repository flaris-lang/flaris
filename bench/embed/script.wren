// see script.fls for what this is
var Sum = Fn.new { |n|
  var s = 0
  var i = 1
  while (i <= n) {
    s = s + i
    i = i + 1
  }
  return s
}

var total = Sum.call(1000)

var Total = Fn.new { total }
var Update = Fn.new { |n| n + 1 }
