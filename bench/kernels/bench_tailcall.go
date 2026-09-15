// bench_tailcall.go - self-recursive tail call, depth 2,000,000
package main

import (
	"fmt"
	"time"
)

func tailsum(n int64, acc int64) int64 {
	if n == 0 {
		return acc
	}
	return tailsum(n-1, acc+n)
}

func main() {
	n := int64(2000000)
	start := time.Now()
	result := tailsum(n, 0)
	ms := time.Since(start).Milliseconds()
	fmt.Printf("result: %d\nelapsed: %d ms\n", result, ms)
}
