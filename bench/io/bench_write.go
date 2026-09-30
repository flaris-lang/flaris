// Write a million formatted lines. See bench_write.c for what this measures.
package main

import (
	"bufio"
	"fmt"
	"os"
	"time"
)

const lines = 1000000

func main() {
	t0 := time.Now()
	f, err := os.Create("io_out_go.txt")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	w := bufio.NewWriter(f)
	for i := 0; i < lines; i++ {
		fmt.Fprintf(w, "%d payload %d\n", i, i*7%9973)
	}
	w.Flush()
	f.Close()
	ms := time.Since(t0).Milliseconds()

	st, _ := os.Stat("io_out_go.txt")
	size := st.Size()
	os.Remove("io_out_go.txt")
	fmt.Printf("result: %d\n", size)
	fmt.Printf("elapsed: %d\n", ms)
}
