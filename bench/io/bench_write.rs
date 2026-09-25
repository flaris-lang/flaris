// Write a million formatted lines. See bench_write.c for what this measures.
use std::fs;
use std::io::{BufWriter, Write};
use std::time::Instant;

const LINES: i64 = 1000000;

fn main() {
    let t0 = Instant::now();
    let f = fs::File::create("io_out_rs.txt").expect("cannot write io_out_rs.txt");
    {
        let mut w = BufWriter::new(&f);
        for i in 0..LINES {
            writeln!(w, "{} payload {}", i, i * 7 % 9973).unwrap();
        }
        w.flush().unwrap();
    }
    drop(f);
    let ms = t0.elapsed().as_millis();

    let size = fs::metadata("io_out_rs.txt").unwrap().len();
    fs::remove_file("io_out_rs.txt").ok();
    println!("result: {}", size);
    println!("elapsed: {}", ms);
}
