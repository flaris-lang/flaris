-- Write a million formatted lines. See bench_write.c for what this measures.
local LINES = 1000000
local t0 = os.clock()
local f = io.open("io_out_lua.txt", "wb")
for i = 0, LINES - 1 do
    f:write(i, " payload ", (i * 7) % 9973, "\n")
end
f:close()
local ms = (os.clock() - t0) * 1000
local r = io.open("io_out_lua.txt", "rb")
local size = r:seek("end")
r:close()
os.remove("io_out_lua.txt")
print(string.format("result: %d", size))
print(string.format("elapsed: %.0f", ms))
