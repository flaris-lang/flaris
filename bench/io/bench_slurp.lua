-- Read the whole file into memory. See bench_slurp.c for what this measures.
local t0 = os.clock()
local f = io.open("io_input.txt", "rb")
local data = f:read("a")
f:close()
local ms = (os.clock() - t0) * 1000
print(string.format("result: %d", #data))
print(string.format("elapsed: %.0f", ms))
