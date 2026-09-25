// Count lines and bytes, one line at a time. See bench_readlines.c for the
// result fold. Scanner strips the terminator, so it is added back.
package main

import (
	"bufio"
	"fmt"
	"os"
	"time"
)

func main() {
	t0 := time.Now()
	f, err := os.Open("io_input.txt")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	lines, total := int64(0), int64(0)
	for sc.Scan() {
		lines++
		total += int64(len(sc.Bytes())) + 1
	}
	ms := time.Since(t0).Milliseconds()
	fmt.Printf("result: %d\n", lines*100000000+total)
	fmt.Printf("elapsed: %d\n", ms)
}
