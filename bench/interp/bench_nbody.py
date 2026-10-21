# bench_nbody.py - n-body simulation of the Jovian planets, 200k steps of dt = 0.01.
# Dominated by floating-point arithmetic on the fields of five body objects.
# Algorithm from The Computer Language Benchmarks Game. Both energies are negative:
# result = round(-e0 * 1e9) + round(-e1 * 1e9), the energy before and after.
import time

PI = 3.141592653589793
SOLAR_MASS = 4 * PI * PI
DAYS_PER_YEAR = 365.24

class Body:
    __slots__ = ('x', 'y', 'z', 'vx', 'vy', 'vz', 'mass')
    def __init__(self, x, y, z, vx, vy, vz, mass):
        self.x = x; self.y = y; self.z = z
        self.vx = vx * DAYS_PER_YEAR; self.vy = vy * DAYS_PER_YEAR; self.vz = vz * DAYS_PER_YEAR
        self.mass = mass * SOLAR_MASS

def make_system():
    return [
        Body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        Body(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
             1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
             9.54791938424326609e-04),
        Body(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
             -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
             2.85885980666130812e-04),
        Body(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
             2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
             4.36624404335156298e-05),
        Body(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
             2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
             5.15138902046611451e-05),
    ]

def offset_momentum(bodies):
    px = py = pz = 0.0
    for b in bodies:
        px += b.vx * b.mass
        py += b.vy * b.mass
        pz += b.vz * b.mass
    sun = bodies[0]
    sun.vx = -px / SOLAR_MASS
    sun.vy = -py / SOLAR_MASS
    sun.vz = -pz / SOLAR_MASS

def energy(bodies):
    e = 0.0
    n = len(bodies)
    for i in range(n):
        bi = bodies[i]
        e += 0.5 * bi.mass * (bi.vx * bi.vx + bi.vy * bi.vy + bi.vz * bi.vz)
        for j in range(i + 1, n):
            bj = bodies[j]
            dx = bi.x - bj.x
            dy = bi.y - bj.y
            dz = bi.z - bj.z
            e -= bi.mass * bj.mass / (dx * dx + dy * dy + dz * dz) ** 0.5
    return e

def advance(bodies, steps, dt):
    n = len(bodies)
    for _ in range(steps):
        for i in range(n):
            bi = bodies[i]
            for j in range(i + 1, n):
                bj = bodies[j]
                dx = bi.x - bj.x
                dy = bi.y - bj.y
                dz = bi.z - bj.z
                d2 = dx * dx + dy * dy + dz * dz
                mag = dt / (d2 * d2 ** 0.5)
                mi = bi.mass * mag
                mj = bj.mass * mag
                bi.vx -= dx * mj
                bi.vy -= dy * mj
                bi.vz -= dz * mj
                bj.vx += dx * mi
                bj.vy += dy * mi
                bj.vz += dz * mi
        for b in bodies:
            b.x += dt * b.vx
            b.y += dt * b.vy
            b.z += dt * b.vz

steps = 200000
bodies = make_system()
offset_momentum(bodies)
t0 = time.perf_counter()
e0 = energy(bodies)
advance(bodies, steps, 0.01)
e1 = energy(bodies)
print("result: %d" % (round(-e0 * 1e9) + round(-e1 * 1e9)))
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
