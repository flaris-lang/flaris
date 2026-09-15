# see script.fls for what this is
(defn sum [n] (var s 0) (var i 1) (while (<= i n) (+= s i) (++ i)) s)
(def total (sum 1000))
(defn Total [] total)
(defn Update [n] (+ n 1))
