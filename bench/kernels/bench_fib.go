// bench_fib.go - recursive Fibonacci, n=38
package main

import (
	"fmt"
	"time"
)

func fib(n int) int64 {
	if n <= 1 {
		return int64(n)
	}
	return fib(n-1) + fib(n-2)
}

func main() {
	n := 38
	start := time.Now()
	result := fib(n)
	ms := time.Since(start).Milliseconds()
	fmt.Printf("result: %d\nelapsed: %d ms\n", result, ms)
}
