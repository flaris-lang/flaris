// bench_nbody.js - n-body simulation of the Jovian planets, 200k steps of dt = 0.01.
// Dominated by floating-point arithmetic on the fields of five body objects.
// Algorithm from The Computer Language Benchmarks Game. Both energies are negative:
// result = round(-e0 * 1e9) + round(-e1 * 1e9), the energy before and after.
const PI = 3.141592653589793;
const SOLAR_MASS = 4 * PI * PI;
const DAYS_PER_YEAR = 365.24;

class Body {
    constructor(x, y, z, vx, vy, vz, mass) {
        this.x = x; this.y = y; this.z = z;
        this.vx = vx * DAYS_PER_YEAR; this.vy = vy * DAYS_PER_YEAR; this.vz = vz * DAYS_PER_YEAR;
        this.mass = mass * SOLAR_MASS;
    }
}

function makeSystem() {
    return [
        new Body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        new Body(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
                 1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
                 9.54791938424326609e-04),
        new Body(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
                 -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
                 2.85885980666130812e-04),
        new Body(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
                 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
                 4.36624404335156298e-05),
        new Body(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
                 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
                 5.15138902046611451e-05),
    ];
}

function offsetMomentum(bodies) {
    let px = 0.0, py = 0.0, pz = 0.0;
    for (const b of bodies) {
        px += b.vx * b.mass;
        py += b.vy * b.mass;
        pz += b.vz * b.mass;
    }
    const sun = bodies[0];
    sun.vx = -px / SOLAR_MASS;
    sun.vy = -py / SOLAR_MASS;
    sun.vz = -pz / SOLAR_MASS;
}

function energy(bodies) {
    let e = 0.0;
    const n = bodies.length;
    for (let i = 0; i < n; i++) {
        const bi = bodies[i];
        e += 0.5 * bi.mass * (bi.vx * bi.vx + bi.vy * bi.vy + bi.vz * bi.vz);
        for (let j = i + 1; j < n; j++) {
            const bj = bodies[j];
            const dx = bi.x - bj.x;
            const dy = bi.y - bj.y;
            const dz = bi.z - bj.z;
            e -= bi.mass * bj.mass / Math.sqrt(dx * dx + dy * dy + dz * dz);
        }
    }
    return e;
}

function advance(bodies, steps, dt) {
    const n = bodies.length;
    for (let s = 0; s < steps; s++) {
        for (let i = 0; i < n; i++) {
            const bi = bodies[i];
            for (let j = i + 1; j < n; j++) {
                const bj = bodies[j];
                const dx = bi.x - bj.x;
                const dy = bi.y - bj.y;
                const dz = bi.z - bj.z;
                const d2 = dx * dx + dy * dy + dz * dz;
                const mag = dt / (d2 * Math.sqrt(d2));
                const mi = bi.mass * mag;
                const mj = bj.mass * mag;
                bi.vx -= dx * mj;
                bi.vy -= dy * mj;
                bi.vz -= dz * mj;
                bj.vx += dx * mi;
                bj.vy += dy * mi;
                bj.vz += dz * mi;
            }
        }
        for (let i = 0; i < n; i++) {
            const b = bodies[i];
            b.x += dt * b.vx;
            b.y += dt * b.vy;
            b.z += dt * b.vz;
        }
    }
}

const steps = 200000;
const bodies = makeSystem();
offsetMomentum(bodies);
const t0 = Date.now();
const e0 = energy(bodies);
advance(bodies, steps, 0.01);
const e1 = energy(bodies);
console.log("result: " + (Math.round(-e0 * 1e9) + Math.round(-e1 * 1e9)));
console.log("elapsed: " + (Date.now() - t0) + " ms");
