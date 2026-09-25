# Write a million formatted lines. See bench_write.c for what this measures.
(def LINES 1000000)
(def t0 (os/clock))
(with [f (file/open "io_out_janet.txt" :wb)]
  (for i 0 LINES
    (file/write f (string i " payload " (% (* i 7) 9973) "\n"))))
(def elapsed (math/floor (* 1000 (- (os/clock) t0))))
(def size (os/stat "io_out_janet.txt" :size))
(os/rm "io_out_janet.txt")
(print "result: " size)
(print "elapsed: " elapsed " ms")
