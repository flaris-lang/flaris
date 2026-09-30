// Read the whole file into memory. See bench_slurp.c for what this measures.
// Squirrel's standard I/O reads blobs and fixed-width numbers; it has neither
// a line reader nor a string write, so this is the one file benchmark it can
// take part in.
local t0 = clock();
local f = file("io_input.txt", "rb");
local data = f.readblob(f.len());
f.close();
local elapsed = ((clock() - t0) * 1000).tointeger();
print("result: " + data.len() + "\n");
print("elapsed: " + elapsed + " ms\n");
