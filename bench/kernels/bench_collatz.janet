# bench_collatz.janet - total Collatz steps for n=1..1,000,000
(defn collatz-steps [start]
  (var n start)
  (var steps 0)
  (while (not= n 1)
    (set n (if (even? n) (div n 2) (+ (* n 3) 1)))
    (++ steps))
  steps)

(def N 1000000)
(def t0 (os/clock))
(var total 0)
(var i 1)
(while (<= i N) (+= total (collatz-steps i)) (++ i))
(def elapsed (math/floor (* 1000 (- (os/clock) t0))))
(print "result: " total)
(print "elapsed: " elapsed " ms")
