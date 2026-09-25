<?php
// Count lines and bytes, one line at a time. See bench_readlines.c for the
// result fold.
$t0 = microtime(true);
$lines = 0; $total = 0;
$f = fopen("io_input.txt", "rb");
while (($line = fgets($f)) !== false) { $lines++; $total += strlen($line); }
fclose($f);
$ms = (microtime(true) - $t0) * 1000;
printf("result: %d\n", $lines * 100000000 + $total);
printf("elapsed: %d\n", (int)$ms);
