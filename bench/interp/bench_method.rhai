// bench_method.rhai - method dispatch on an object map
// A function called as v.AddX(1) gets `this` bound to v itself, so it can update it.
fn AddX(d) { this.x += d; }
fn Dot() { this.x * this.y }

let v = #{ x: 1, y: 3 };
let n = 6000000;
let t0 = timestamp();
let total = 0;
for i in 0..n {
    v.AddX(1);
    total += v.Dot();
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
