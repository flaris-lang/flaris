// bench_regex.swift - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
// NSRegularExpression (ICU): Swift's native Regex gives the same result about 4x slower.
import Foundation

let text = try! String(contentsOfFile: "bench_corpus.txt", encoding: .utf8)
let scans = 5
let re = try! NSRegularExpression(pattern: #"\b\d{4}-\d{2}-\d{2}\b"#)
let range = NSRange(text.startIndex..., in: text)
let clock = ContinuousClock()
let t0 = clock.now
var total = 0
for _ in 0..<scans {
    total += re.numberOfMatches(in: text, range: range)
}
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(total)")
print("elapsed: \(ms) ms")
