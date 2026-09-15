// see script.fls for what this is; ES5 so Duktape can run it too
function sum(n) { var s = 0; for (var i = 1; i <= n; i++) s += i; return s; }
var total = sum(1000);
function Total() { return total; }
function Update(n) { return n + 1; }
