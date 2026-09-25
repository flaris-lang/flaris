// Count lines and bytes, one line at a time. See bench_readlines.c for the
// result fold.
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::time::Instant;

fn main() {
    let t0 = Instant::now();
    let f = File::open("io_input.txt").expect("cannot open io_input.txt");
    let mut r = BufReader::new(f);
    let mut buf = String::new();
    let mut lines: i64 = 0;
    let mut total: i64 = 0;
    loop {
        buf.clear();
        match r.read_line(&mut buf) {
            Ok(0) => break,
            Ok(n) => {
                lines += 1;
                total += n as i64;
            }
            Err(_) => break,
        }
    }
    let ms = t0.elapsed().as_millis();
    println!("result: {}", lines * 100000000 + total);
    println!("elapsed: {}", ms);
}
