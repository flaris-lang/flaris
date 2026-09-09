<?php
// bench_collatz.php - total Collatz steps for n=1..1,000,000
function collatz_steps(int $n): int {
    $steps = 0;
    while ($n != 1) {
        $n = ($n % 2 === 0) ? intdiv($n, 2) : $n * 3 + 1;
        $steps++;
    }
    return $steps;
}

$n = 1000000;
$t0 = microtime(true);
$total = 0;
for ($i = 1; $i <= $n; $i++) $total += collatz_steps($i);
$elapsed = (int)((microtime(true) - $t0) * 1000);
echo "result: $total\n";
echo "elapsed: $elapsed ms\n";
