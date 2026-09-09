# bench_fib.janet - recursive Fibonacci, n=38
(defn fib [n] (if (<= n 1) n (+ (fib (- n 1)) (fib (- n 2)))))

(def t0 (os/clock))
(def result (fib 38))
(def elapsed (math/floor (* 1000 (- (os/clock) t0))))
(print "result: " result)
(print "elapsed: " elapsed " ms")
