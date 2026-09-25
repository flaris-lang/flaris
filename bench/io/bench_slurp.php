<?php
// Read the whole file into memory. See bench_slurp.c for what this measures.
$t0 = microtime(true);
$data = file_get_contents("io_input.txt");
$ms = (microtime(true) - $t0) * 1000;
printf("result: %d\n", strlen($data));
printf("elapsed: %d\n", (int)$ms);
