// Read the whole file into memory. See bench_slurp.c for what this measures.
use std::fs;
use std::time::Instant;

fn main() {
    let t0 = Instant::now();
    let data = fs::read("io_input.txt").expect("cannot open io_input.txt");
    let ms = t0.elapsed().as_millis();
    println!("result: {}", data.len());
    println!("elapsed: {}", ms);
}
