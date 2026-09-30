# Read the whole file into memory. See bench_slurp.c for what this measures.
(def t0 (os/clock))
(def data (slurp "io_input.txt"))
(def elapsed (math/floor (* 1000 (- (os/clock) t0))))
(print "result: " (length data))
(print "elapsed: " elapsed " ms")
