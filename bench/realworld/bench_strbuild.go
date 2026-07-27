// bench_strbuild.go - build a large string, N times, via strings.Builder
// (Go's idiomatic linear builder; naive s += is O(n^2) because strings are
// immutable). result is the final byte length.
package main

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

func main() {
	N := 1000000
	t0 := time.Now()
	var sb strings.Builder
	for i := 0; i < N; i++ {
		sb.WriteString("item_")
		sb.WriteString(strconv.Itoa(i))
		sb.WriteString(";")
	}
	result := sb.Len()
	elapsed := time.Since(t0).Milliseconds()
	fmt.Printf("result: %d\n", result)
	fmt.Printf("elapsed: %d ms\n", elapsed)
}
