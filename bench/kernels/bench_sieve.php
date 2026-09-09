<?php
// bench_sieve.php - Sieve of Eratosthenes, N=10,000,000
// A PHP string is a byte buffer; $s[$i] reads and writes one byte.
function sieve(int $n): int {
    $flags = str_repeat("\x01", $n + 1);
    $flags[0] = "\x00";
    $flags[1] = "\x00";
    $pMax = (int)sqrt($n);
    for ($p = 2; $p <= $pMax; $p++) {
        if ($flags[$p] === "\x01") {
            for ($i = $p * $p; $i <= $n; $i += $p) $flags[$i] = "\x00";
        }
    }
    $count = 0;
    for ($i = 2; $i <= $n; $i++) if ($flags[$i] === "\x01") $count++;
    return $count;
}

$n = 10000000;
$t0 = microtime(true);
$result = sieve($n);
$elapsed = (int)((microtime(true) - $t0) * 1000);
echo "result: $result\n";
echo "elapsed: $elapsed ms\n";
