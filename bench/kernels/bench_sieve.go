// bench_sieve.go - Sieve of Eratosthenes, N=10,000,000
package main

import (
	"fmt"
	"time"
)

func sieve(N int) int {
	flags := make([]byte, N+1)
	for i := range flags {
		flags[i] = 1
	}
	flags[0] = 0
	flags[1] = 0
	for p := 2; p*p <= N; p++ {
		if flags[p] == 1 {
			for i := p * p; i <= N; i += p {
				flags[i] = 0
			}
		}
	}
	count := 0
	for i := 2; i <= N; i++ {
		if flags[i] == 1 {
			count++
		}
	}
	return count
}

func main() {
	N := 10000000
	start := time.Now()
	count := sieve(N)
	ms := time.Since(start).Milliseconds()
	fmt.Printf("result: %d\nelapsed: %d ms\n", count, ms)
}
