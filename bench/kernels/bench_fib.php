<?php
// bench_fib.php - recursive Fibonacci, n=38
function fib(int $n): int { return $n <= 1 ? $n : fib($n - 1) + fib($n - 2); }

$t0 = microtime(true);
$result = fib(38);
$elapsed = (int)((microtime(true) - $t0) * 1000);
echo "result: $result\n";
echo "elapsed: $elapsed ms\n";
