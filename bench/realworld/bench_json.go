// bench_json.go - parse an 18 MB JSON array, ITERS times, summing value fields.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

// All four fields are decoded, so Go materialises the same data as every other
// language here. Omitting them would let encoding/json skip most of the record
// and would not be measuring the same workload.
type Rec struct {
	Id     int64  `json:"id"`
	Name   string `json:"name"`
	Value  int64  `json:"value"`
	Active bool   `json:"active"`
}

func main() {
	data, _ := os.ReadFile("bench_data.json")
	iters := 5
	t0 := time.Now()
	var total int64 = 0
	for k := 0; k < iters; k++ {
		var arr []Rec
		json.Unmarshal(data, &arr)
		for i := range arr {
			total += arr[i].Value
		}
	}
	elapsed := time.Since(t0).Milliseconds()
	fmt.Printf("result: %d\n", total)
	fmt.Printf("elapsed: %d ms\n", elapsed)
}
