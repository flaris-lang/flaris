class Vec {
    constructor(x, y) { this.x = x; this.y = y; }
    AddX(d) { this.x = this.x + d; }
    Dot() { return this.x * this.y; }
}
const v = new Vec(1, 3);
const n = 6000000;
const t0 = Date.now();
let total = 0;
for (let i = 0; i < n; i++) { v.AddX(1); total += v.Dot(); }
console.log("result: " + total);
console.log("elapsed: " + (Date.now() - t0) + " ms");
