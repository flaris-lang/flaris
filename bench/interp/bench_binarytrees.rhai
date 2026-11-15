// bench_binarytrees.rhai
// check is a method: `this` binds to the node in place, where a plain argument
// would copy the whole subtree on every call.
fn bottom_up(d) {
    if d <= 0 { return [(), ()]; }
    [bottom_up(d - 1), bottom_up(d - 1)]
}
fn check() {
    if this[0] == () { return 1; }
    1 + this[0].check() + this[1].check()
}

let max_depth = 16;
let t0 = timestamp();
let total = 0;
let d = 4;
while d <= max_depth {
    let iters = 1 << (max_depth - d + 4);
    for i in 0..iters { total += bottom_up(d).check(); }
    d += 2;
}
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + total);
print("elapsed: " + elapsed + " ms");
