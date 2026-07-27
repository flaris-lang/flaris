// bench_collatz.go - total Collatz steps for n=1..1,000,000
package main

import (
	"fmt"
	"time"
)

func collatzSteps(n int64) int64 {
	var steps int64
	for n != 1 {
		if n&1 == 1 {
			n = n*3 + 1
		} else {
			n >>= 1
		}
		steps++
	}
	return steps
}

func main() {
	var N int64 = 1000000
	start := time.Now()
	var total int64
	for i := int64(1); i <= N; i++ {
		total += collatzSteps(i)
	}
	ms := time.Since(start).Milliseconds()
	fmt.Printf("result: %d\nelapsed: %d ms\n", total, ms)
}
