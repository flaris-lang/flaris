# Count lines and bytes, one line at a time. See bench_readlines.c for the
# result fold. Reading with :line keeps the terminator.
(def t0 (os/clock))
(var lines 0)
(var total 0)
(with [f (file/open "io_input.txt" :rb)]
  (while (def line (file/read f :line))
    (++ lines)
    (+= total (length line))))
(def elapsed (math/floor (* 1000 (- (os/clock) t0))))
(print "result: " (+ (* lines 100000000) total))
(print "elapsed: " elapsed " ms")
