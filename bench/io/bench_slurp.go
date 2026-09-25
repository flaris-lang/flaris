// Read the whole file into memory. See bench_slurp.c for what this measures.
package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	t0 := time.Now()
	data, err := os.ReadFile("io_input.txt")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	ms := time.Since(t0).Milliseconds()
	fmt.Printf("result: %d\n", len(data))
	fmt.Printf("elapsed: %d\n", ms)
}
