-- bench_nbody.luau - n-body simulation of the Jovian planets, 200k steps of dt = 0.01.
-- Dominated by floating-point arithmetic on the fields of five body tables.
-- Algorithm from The Computer Language Benchmarks Game. Both energies are negative:
-- result = round(-e0 * 1e9) + round(-e1 * 1e9), the energy before and after.
local PI = 3.141592653589793
local SOLAR_MASS = 4 * PI * PI
local DAYS_PER_YEAR = 365.24

local function body(x, y, z, vx, vy, vz, mass)
    return {
        x = x, y = y, z = z,
        vx = vx * DAYS_PER_YEAR, vy = vy * DAYS_PER_YEAR, vz = vz * DAYS_PER_YEAR,
        mass = mass * SOLAR_MASS,
    }
end

local function make_system()
    return {
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
    }
end

local function offset_momentum(bodies)
    local px, py, pz = 0.0, 0.0, 0.0
    for i = 1, #bodies do
        local b = bodies[i]
        px = px + b.vx * b.mass
        py = py + b.vy * b.mass
        pz = pz + b.vz * b.mass
    end
    local sun = bodies[1]
    sun.vx = -px / SOLAR_MASS
    sun.vy = -py / SOLAR_MASS
    sun.vz = -pz / SOLAR_MASS
end

local function energy(bodies)
    local e = 0.0
    local n = #bodies
    for i = 1, n do
        local bi = bodies[i]
        e = e + 0.5 * bi.mass * (bi.vx * bi.vx + bi.vy * bi.vy + bi.vz * bi.vz)
        for j = i + 1, n do
            local bj = bodies[j]
            local dx = bi.x - bj.x
            local dy = bi.y - bj.y
            local dz = bi.z - bj.z
            e = e - bi.mass * bj.mass / math.sqrt(dx * dx + dy * dy + dz * dz)
        end
    end
    return e
end

local function advance(bodies, steps, dt)
    local sqrt = math.sqrt
    local n = #bodies
    for _ = 1, steps do
        for i = 1, n do
            local bi = bodies[i]
            for j = i + 1, n do
                local bj = bodies[j]
                local dx = bi.x - bj.x
                local dy = bi.y - bj.y
                local dz = bi.z - bj.z
                local d2 = dx * dx + dy * dy + dz * dz
                local mag = dt / (d2 * sqrt(d2))
                local mi = bi.mass * mag
                local mj = bj.mass * mag
                bi.vx = bi.vx - dx * mj
                bi.vy = bi.vy - dy * mj
                bi.vz = bi.vz - dz * mj
                bj.vx = bj.vx + dx * mi
                bj.vy = bj.vy + dy * mi
                bj.vz = bj.vz + dz * mi
            end
        end
        for i = 1, n do
            local b = bodies[i]
            b.x = b.x + dt * b.vx
            b.y = b.y + dt * b.vy
            b.z = b.z + dt * b.vz
        end
    end
end

local steps = 200000
local bodies = make_system()
offset_momentum(bodies)
local t0 = os.clock()
local e0 = energy(bodies)
advance(bodies, steps, 0.01)
local e1 = energy(bodies)
local result = math.floor(-e0 * 1e9 + 0.5) + math.floor(-e1 * 1e9 + 0.5)
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. result)
print("elapsed: " .. elapsed .. " ms")
