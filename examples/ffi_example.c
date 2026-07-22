// ffi_example.c - Flaris FFI Plugin Example
//
// Demonstrates:
//   - Helper functions for building FfiObject return values
//   - Argument validation patterns
//   - Callback registration and invocation
//   - Block (zero-copy buffer) usage
//   - Array construction
//
// Compile (Linux):
//   cc -shared -fPIC -o plugin.so ffi_example.c
//
// Compile (macOS):
//   cc -shared -fPIC -undefined dynamic_lookup -o plugin.dylib ffi_example.c
//
// Get SHA-256 for Ffi.Load:
//   sha256sum plugin.so     (Linux)
//   shasum -a 256 plugin.dylib  (macOS)

#include "../vm/ffi_object.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>


// ─────────────────────────────────────────────────────────────────────────────
// Section 1 - Helpers
//
// These make constructing return values clean and consistent.
// Copy this section into your own plugin or a shared header.
// ─────────────────────────────────────────────────────────────────────────────

static FfiObject make_nil(void)
{
    return (FfiObject){ .type = FFIVAL_NIL };
}

static FfiObject make_int(int64_t v)
{
    FfiObject o = { .type = FFIVAL_INT };
    o.ival = v;
    return o;
}

static FfiObject make_float(double v)
{
    FfiObject o = { .type = FFIVAL_FLOAT };
    o.fval = v;
    return o;
}

static FfiObject make_bool(int v)
{
    FfiObject o = { .type = FFIVAL_BOOL };
    o.ival = v ? 1 : 0;
    return o;
}

// The VM takes ownership of the string data - it must be malloc'd.
// make_string duplicates the input so the caller keeps ownership of src.
static FfiObject make_string(const char *src)
{
    FfiObject o = { .type = FFIVAL_STRING };
    o.string.data   = src ? strdup(src) : strdup("");
    o.string.length = (uint32_t)(src ? strlen(src) : 0);
    return o;
}

// Zero-copy block. 'memory' must remain valid until the FFI call returns.
// The VM never frees block memory. Use for large buffers you own.
static FfiObject make_block(void *memory, uint8_t block_size, uint32_t block_count)
{
    FfiObject o = { .type = FFIVAL_BLOCK };
    o.block.memory      = memory;
    o.block.block_size  = block_size;
    o.block.block_count = block_count;
    return o;
}

// Build an array of n FfiObjects (one contiguous allocation, all elements
// nil). Fill via arr.array.elements[i] = make_int(...). ffi_array_n comes
// from ffi_object.h; the VM takes ownership of the whole array.
static FfiObject make_array(uint32_t n)
{
    return ffi_array_n(n);
}


// Build an object (key-value map) of n pairs (one contiguous allocation,
// keys NULL, values nil). Fill via object_set() below. ffi_object_n comes
// from ffi_object.h; the VM takes ownership of all keys and values.
static FfiObject make_object(uint32_t n)
{
    return ffi_object_n(n);
}

// Set a key-value pair in an object at index i.
// key is duplicated - caller retains ownership of the key string.
// val is copied by value into the pair.
static void object_set(FfiObject *obj, uint32_t i, const char *key, FfiObject val)
{
    if(obj->object.pairs[i].key)
        free((void*)obj->object.pairs[i].key);

    obj->object.pairs[i].key   = strdup(key);
    obj->object.pairs[i].value = val;
}


// ─────────────────────────────────────────────────────────────────────────────
// Section 2 - Callback Setup
//
// Export flaris_set_callback - Flaris calls this once when
// Ffi.SetCallback(handle, name, fn) is called from Flaris code.
//
// ─────────────────────────────────────────────────────────────────────────────

typedef FfiObject (*FlarisDispatch)(const char *name, FfiObject *args, int argc);
static FlarisDispatch g_dispatch = NULL;

// Must export this - Flaris calls it once at SetCallback time
void flaris_set_callback(FlarisDispatch dispatch) {
    g_dispatch = dispatch;
}

// Convenience wrapper: call a named Flaris function with an array of args.
// Returns ffi_nil() if no dispatcher is registered.
static FfiObject call_flaris(const char *name, FfiObject *args, int argc)
{
    if (!g_dispatch)
        return make_nil();
    return g_dispatch(name, args, argc);
}


// ─────────────────────────────────────────────────────────────────────────────
// Section 3 - Example Functions
// ─────────────────────────────────────────────────────────────────────────────

// ffi_add(a: int, b: int) - int
// Basic arithmetic - demonstrates argument validation and int return.
FfiObject ffi_add(FfiObject *args, int argc)
{
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_INT);
    return make_int(AS_INT(args[0]) + AS_INT(args[1]));
}

// ffi_greet(name: string) - string
// Demonstrates string argument and heap-allocated string return.
FfiObject ffi_greet(FfiObject *args, int argc)
{
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_STRING);

    const char *name = AS_STRING(args[0]);
    char buf[256];
    snprintf(buf, sizeof(buf), "Hello, %s!", name);
    return make_string(buf);  // make_string duplicates buf
}

// ffi_sum_block(buf: block) - float
// Demonstrates zero-copy block access.
// Interprets the block as an array of float32 values and returns their sum.
FfiObject ffi_sum_block(FfiObject *args, int argc)
{
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_BLOCK);

    float   *data  = (float *)args[0].block.memory;
    uint32_t count = args[0].block.block_count;

    double sum = 0.0;
    for (uint32_t i = 0; i < count; i++)
        sum += data[i];

    return make_float(sum);
}

// ffi_make_pair(a: int, b: float) - array
// Demonstrates returning an array with mixed types.
FfiObject ffi_make_pair(FfiObject *args, int argc)
{
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_FLOAT);

    FfiObject arr = make_array(2);
    arr.array.elements[0] = make_int(AS_INT(args[0]));
    arr.array.elements[1] = make_float(AS_FLOAT(args[1]));
    return arr;
}

// ffi_trigger(value: int) - int
// Demonstrates calling back into Flaris.
// Calls the Flaris function registered as "ondata", passes value as arg,
// and returns the result from Flaris back to the caller.
FfiObject ffi_trigger(FfiObject *args, int argc)
{
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_INT);

    int64_t value = AS_INT(args[0]);

    // Build args for the Flaris callback
    FfiObject cb_args[2];
    cb_args[0] = make_int(value);
    cb_args[1] = make_string("processed");

    FfiObject result = call_flaris("ondata", cb_args, 2);
    return result;
}

// ffi_process_block(buf: block) - int
// Processes binary data in the block, fires "onchunk" callback with
// a summary int, and returns number of bytes processed.
FfiObject ffi_process_block(FfiObject *args, int argc)
{
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_BLOCK);
    uint8_t *mem   = (uint8_t *)args[0].block.memory;
    uint32_t count = args[0].block.block_count;
    uint8_t  bsize = args[0].block.block_size;
    uint64_t total = (uint64_t)count * bsize;

    // Compute checksum over raw bytes
    uint64_t checksum = 0;
    for (uint64_t i = 0; i < total; i++)
        checksum ^= mem[i];

    // Notify Flaris: send checksum and byte count as ints
    FfiObject cb_args[2];
    cb_args[0] = make_int((int64_t)checksum);
    cb_args[1] = make_int((int64_t)total);
    call_flaris("onchunk", cb_args, 2);

    return make_int((int64_t)total);
}

// ffi_version() - int
// Simple function with no args, returns a version number as int.
uint32_t flaris_version(void) {
    return 0x01000000;  // 1.0.0.0
}