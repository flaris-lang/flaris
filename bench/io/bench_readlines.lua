-- Count lines and bytes, one line at a time. See bench_readlines.c for the
-- result fold. io.lines strips the terminator, so it is added back.
local t0 = os.clock()
local lines, total = 0, 0
for line in io.lines("io_input.txt") do
    lines = lines + 1
    total = total + #line + 1
end
local ms = (os.clock() - t0) * 1000
print(string.format("result: %.0f", lines * 100000000 + total))
print(string.format("elapsed: %.0f", ms))
