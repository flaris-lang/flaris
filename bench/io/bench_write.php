<?php
// Write a million formatted lines. See bench_write.c for what this measures.
$LINES = 1000000;
$t0 = microtime(true);
$f = fopen("io_out_php.txt", "wb");
for ($i = 0; $i < $LINES; $i++) {
    fwrite($f, $i . " payload " . (($i * 7) % 9973) . "\n");
}
fclose($f);
$ms = (microtime(true) - $t0) * 1000;
$size = filesize("io_out_php.txt");
unlink("io_out_php.txt");
printf("result: %d\n", $size);
printf("elapsed: %d\n", (int)$ms);
