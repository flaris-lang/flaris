// bench_json.swift - parse an 18 MB JSON array, ITERS times, summing value fields.
// Codable decodes all four fields into a typed struct, like the Go port.
import Foundation

struct Rec: Decodable {
    let id: Int
    let name: String
    let value: Int
    let active: Bool
}

let data = try! Data(contentsOf: URL(fileURLWithPath: "bench_data.json"))
let iters = 5
let clock = ContinuousClock()
let t0 = clock.now
var total = 0
for _ in 0..<iters {
    let arr = try! JSONDecoder().decode([Rec].self, from: data)
    for rec in arr {
        total += rec.value
    }
}
let ms = Int((clock.now - t0) / .milliseconds(1))
print("result: \(total)")
print("elapsed: \(ms) ms")
