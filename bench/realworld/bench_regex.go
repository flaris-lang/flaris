// bench_regex.go - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
// Go's regexp is RE2 (linear, no backtracking).
package main

import (
	"fmt"
	"os"
	"regexp"
	"time"
)

func main() {
	data, _ := os.ReadFile("bench_corpus.txt")
	scans := 5
	re := regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}\b`)
	t0 := time.Now()
	total := 0
	for k := 0; k < scans; k++ {
		total += len(re.FindAllIndex(data, -1))
	}
	elapsed := time.Since(t0).Milliseconds()
	fmt.Printf("result: %d\n", total)
	fmt.Printf("elapsed: %d ms\n", elapsed)
}
