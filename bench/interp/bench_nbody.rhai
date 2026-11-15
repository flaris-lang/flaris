// bench_nbody.rhai - n-body simulation of the Jovian planets, 200k steps of dt = 0.01.
// Dominated by floating-point arithmetic on the fields of five body maps.
// Algorithm from The Computer Language Benchmarks Game. Both energies are negative:
// result = round(-e0 * 1e9) + round(-e1 * 1e9), the energy before and after.
// Maps are values, so the functions that move the bodies are methods: `this` is the
// bodies array itself, and this[i].vx updates body i in place.
const PI = 3.141592653589793;
const SOLAR_MASS = 4.0 * PI * PI;
const DAYS_PER_YEAR = 365.24;

fn body(x, y, z, vx, vy, vz, mass) {
    #{
        x: x, y: y, z: z,
        vx: vx * global::DAYS_PER_YEAR, vy: vy * global::DAYS_PER_YEAR, vz: vz * global::DAYS_PER_YEAR,
        mass: mass * global::SOLAR_MASS,
    }
}

fn make_system() {
    [
        body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        body(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
             1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
             9.54791938424326609e-04),
        body(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
             -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
             2.85885980666130812e-04),
        body(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
             2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
             4.36624404335156298e-05),
        body(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
             2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
             5.15138902046611451e-05),
    ]
}

fn offset_momentum() {
    let px = 0.0; let py = 0.0; let pz = 0.0;
    for b in this {
        px += b.vx * b.mass;
        py += b.vy * b.mass;
        pz += b.vz * b.mass;
    }
    this[0].vx = -px / global::SOLAR_MASS;
    this[0].vy = -py / global::SOLAR_MASS;
    this[0].vz = -pz / global::SOLAR_MASS;
}

fn energy(bodies) {
    let e = 0.0;
    let n = bodies.len();
    for i in 0..n {
        let bi = bodies[i];
        e += 0.5 * bi.mass * (bi.vx * bi.vx + bi.vy * bi.vy + bi.vz * bi.vz);
        for j in (i + 1)..n {
            let bj = bodies[j];
            let dx = bi.x - bj.x;
            let dy = bi.y - bj.y;
            let dz = bi.z - bj.z;
            e -= bi.mass * bj.mass / sqrt(dx * dx + dy * dy + dz * dz);
        }
    }
    e
}

fn advance(steps, dt) {
    let n = this.len();
    for s in 0..steps {
        for i in 0..n {
            for j in (i + 1)..n {
                let dx = this[i].x - this[j].x;
                let dy = this[i].y - this[j].y;
                let dz = this[i].z - this[j].z;
                let d2 = dx * dx + dy * dy + dz * dz;
                let mag = dt / (d2 * sqrt(d2));
                let mi = this[i].mass * mag;
                let mj = this[j].mass * mag;
                this[i].vx -= dx * mj;
                this[i].vy -= dy * mj;
                this[i].vz -= dz * mj;
                this[j].vx += dx * mi;
                this[j].vy += dy * mi;
                this[j].vz += dz * mi;
            }
        }
        for i in 0..n {
            this[i].x += dt * this[i].vx;
            this[i].y += dt * this[i].vy;
            this[i].z += dt * this[i].vz;
        }
    }
}

let steps = 200000;
let bodies = make_system();
bodies.offset_momentum();
let t0 = timestamp();
let e0 = energy(bodies);
bodies.advance(steps, 0.01);
let e1 = energy(bodies);
let result = (-e0 * 1e9 + 0.5).floor().to_int() + (-e1 * 1e9 + 0.5).floor().to_int();
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + result);
print("elapsed: " + elapsed + " ms");
