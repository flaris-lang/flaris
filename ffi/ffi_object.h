#ifndef FFIOBJECT_H
#define FFIOBJECT_H

#include <stdint.h>

/*
 * ffi_object.h - the only header a Flaris FFI plugin needs to include.
 *
 * It defines the FfiObject marshalling struct plus a set of convenience
 * macros and `static inline` helpers for inspecting arguments and building
 * return values. The helpers do not change the struct layout, so a plugin
 * built against this header stays ABI-compatible with the matching VM.
 *
 * Constructors that allocate (ffi_string, ffi_array_n, ffi_object_n,
 * ffi_table_n, ffi_object_get) need malloc/strdup. Define FFI_OBJECT_NO_STDLIB
 * before including to drop those helpers (and the <stdlib.h>/<string.h>
 * includes) for freestanding builds.
 */
#ifndef FFI_OBJECT_NO_STDLIB
#include <stdlib.h>
#include <string.h>
#endif

/* ── ABI version ────────────────────────────────────────────────────────────
 *
 * FfiObject's layout is shared between the VM and every plugin, so a plugin
 * built against a different revision of this header would misread every
 * argument - undefined behaviour, not a clean error. The version below is
 * bumped whenever that layout changes.
 *
 * Every plugin must invoke FLARIS_PLUGIN_ABI() exactly once at file scope:
 *
 *     #include "ffi_object.h"
 *     FLARIS_PLUGIN_ABI()
 *
 * It exports flaris_abi_version(), which the runtime checks at Ffi.Load. A
 * plugin reporting a version the runtime does not know is refused; a plugin
 * exporting nothing is currently loaded with a warning, since it cannot be
 * told apart from a shared library that is not a plugin at all.
 */
#define FLARIS_FFI_ABI_VERSION 1u

#if defined(_WIN32)
#  define FFI_EXPORT __declspec(dllexport)
#else
#  define FFI_EXPORT __attribute__((visibility("default")))
#endif

#define FLARIS_PLUGIN_ABI()                                  \
    FFI_EXPORT uint32_t flaris_abi_version(void)             \
    {                                                        \
        return FLARIS_FFI_ABI_VERSION;                       \
    }

typedef enum
{
    FFIVAL_NIL,
    FFIVAL_CHAR,
    FFIVAL_FLOAT,
    FFIVAL_INT,
    FFIVAL_STRING,
    FFIVAL_OBJECT,
    FFIVAL_ARRAY,
    FFIVAL_BOOL,
    FFIVAL_BLOCK,
    FFIVAL_FUNC,
    FFIVAL_TABLE,
} FfiObjectType;

typedef struct FfiObject FfiObject;
typedef struct FfiKV FfiKV;
typedef FfiObject (*FFIFunc)(FfiObject *args, int argc);

/* ── FfiObject.flags bits ───────────────────────────────────────────────────
 *
 * FFI_FLAG_BORROWED (FFIVAL_STRING / FFIVAL_BLOCK arguments, set by the
 * runtime): the pointed-to memory belongs to the caller and is only valid for
 * the duration of the plugin call. Strings: read freely while your function
 * runs; memcpy the bytes if you need them afterwards; never free() or write
 * through the pointer. Blocks: shared memory, writable by convention, never
 * free() or realloc().
 *
 * Rules for plugin code:
 *   - Treat every incoming argument as read-only unless documented otherwise
 *     (BLOCK memory is the documented exception - it is shared and writable).
 *   - Build return values with the ffi_* constructors below and leave `flags`
 *     as they set it (0). All other bits are reserved by the runtime.
 *   - A returned string must be a malloc'd buffer the runtime can take
 *     ownership of (ffi_string / ffi_string_n do this for you); do not return
 *     pointers to static, stack, or argument memory.
 */
#define FFI_FLAG_BORROWED 0x1u

struct FfiObject
{
    FfiObjectType type;
    uint32_t flags;

    union
    {

        double fval;
        int64_t ival;
        FFIFunc fn;

        struct
        {
            char *data;
            uint32_t length;
        } string;

        struct
        {
            FfiKV *pairs; /* contiguous; each pair embeds its value */
            uint32_t length;
        } object;

        struct
        {
            FfiObject *elements; /* contiguous value array, NOT pointers */
            uint32_t length;
        } array;

        struct
        {
            void *memory;
            uint8_t block_size;
            uint32_t block_count;
        } block;

        /* Rowset: column names stated once + cells in row-major order.
         * cell (r, c) lives at cells[r * ncols + c]. The runtime converts a
         * table to an array of objects ({ col: value, ... } per row), so
         * script code sees the same shape a FFIVAL_ARRAY of FFIVAL_OBJECT
         * rows would produce, while hashing each column name once per table
         * rather than once per row: measured ~1.5x faster to marshal on a
         * 500-row, 2-column result. Use this for anything row-shaped
         * (database results, CSV, etc.). */
        struct
        {
            char **col_names;    /* ncols malloc'd names, owned by this node */
            FfiObject *cells;    /* nrows*ncols cells, owned by this node */
            uint32_t ncols;
            uint32_t nrows;
        } table;
    };
};

struct FfiKV
{
    char *key;
    FfiObject value; /* embedded by value, not a pointer */
};

/* ── Type checks (take FfiObject by value) ─────────────────────────────────── */
#define IS_NIL(v) ((v).type == FFIVAL_NIL)
#define IS_CHAR(v) ((v).type == FFIVAL_CHAR)
#define IS_INT(v) ((v).type == FFIVAL_INT)
#define IS_FLOAT(v) ((v).type == FFIVAL_FLOAT)
#define IS_STRING(v) ((v).type == FFIVAL_STRING)
#define IS_BOOL(v) ((v).type == FFIVAL_BOOL)
#define IS_ARRAY(v) ((v).type == FFIVAL_ARRAY)
#define IS_OBJECT(v) ((v).type == FFIVAL_OBJECT)
#define IS_BLOCK(v) ((v).type == FFIVAL_BLOCK)
#define IS_FUNC(v) ((v).type == FFIVAL_FUNC)
#define IS_TABLE(v) ((v).type == FFIVAL_TABLE)
#define IS_NUMBER(v) (IS_INT(v) || IS_FLOAT(v))

/* ── Value accessors (take FfiObject by value) ─────────────────────────────── */
#define AS_INT(v) ((v).ival)
#define AS_FLOAT(v) ((v).fval)
#define AS_CHAR(v) ((v).ival)
#define AS_STRING(v) ((v).string.data)
#define AS_STRING_LEN(v) ((v).string.length)
#define AS_BOOL(v) ((v).ival != 0)
/* Numeric arg as double regardless of int/float storage. */
#define AS_NUMBER(v) (IS_FLOAT(v) ? (v).fval : (double)(v).ival)

/* ── Container accessors ───────────────────────────────────────────────────── */
/* NOTE: FFI_ARR_AT / FFI_OBJ_VAL yield an FfiObject VALUE, not a
 * pointer. Use `FfiObject e = FFI_ARR_AT(v, i);` or take &FFI_ARR_AT(v, i). */
#define FFI_ARR_LEN(v) ((v).array.length)
#define FFI_ARR_AT(v, i) ((v).array.elements[i])
#define FFI_OBJ_LEN(v) ((v).object.length)
#define FFI_OBJ_KEY(v, i) ((v).object.pairs[i].key)
#define FFI_OBJ_VAL(v, i) ((v).object.pairs[i].value)
/* Total byte size of a block: block_size * block_count. */
#define FFI_BLOCK_BYTES(v) ((uint64_t)(v).block.block_size * (uint64_t)(v).block.block_count)
#define FFI_BLOCK_PTR(v) ((v).block.memory)
/* Table accessors: cell (r, c) in row-major order. */
#define FFI_TBL_ROWS(v) ((v).table.nrows)
#define FFI_TBL_COLS(v) ((v).table.ncols)
#define FFI_TBL_NAME(v, c) ((v).table.col_names[c])
#define FFI_TBL_CELL(v, r, c) ((v).table.cells[(uint64_t)(r) * (v).table.ncols + (c)])

/* ── Version helper: pack maj.min.patch.build into 0xMMmmppbb ───────────────── */
#define FLARIS_VERSION(maj, min, pat, bld)        \
    (((uint32_t)(maj) << 24) | ((uint32_t)(min) << 16) | \
     ((uint32_t)(pat) << 8) | (uint32_t)(bld))

/* ── Return-value constructors ─────────────────────────────────────────────── */
static inline FfiObject ffi_nil(void)
{
    FfiObject v = {0};
    v.type = FFIVAL_NIL;
    return v;
}
static inline FfiObject ffi_int(int64_t x)
{
    FfiObject v = {0};
    v.type = FFIVAL_INT;
    v.ival = x;
    return v;
}
static inline FfiObject ffi_float(double x)
{
    FfiObject v = {0};
    v.type = FFIVAL_FLOAT;
    v.fval = x;
    return v;
}
static inline FfiObject ffi_bool(int b)
{
    FfiObject v = {0};
    v.type = FFIVAL_BOOL;
    v.ival = b ? 1 : 0;
    return v;
}
static inline FfiObject ffi_char(int64_t codepoint)
{
    FfiObject v = {0};
    v.type = FFIVAL_CHAR;
    v.ival = codepoint;
    return v;
}
static inline FfiObject ffi_func(FFIFunc f)
{
    FfiObject v = {0};
    v.type = FFIVAL_FUNC;
    v.fn = f;
    return v;
}

#ifndef FFI_OBJECT_NO_STDLIB
/* Returns a string the VM takes ownership of after conversion; NULL yields nil. */
static inline FfiObject ffi_string_n(const char *s, uint32_t len)
{
    if (!s)
        return ffi_nil();
    char *copy = (char *)malloc((size_t)len + 1);
    if (!copy)
        return ffi_nil();
    memcpy(copy, s, len);
    copy[len] = '\0';
    FfiObject v = {0};
    v.type = FFIVAL_STRING;
    v.string.data = copy;
    v.string.length = len;
    return v;
}
static inline FfiObject ffi_string(const char *s)
{
    return s ? ffi_string_n(s, (uint32_t)strlen(s)) : ffi_nil();
}

/* Array of n elements in ONE allocation, all initialised to nil. Fill via
 * FFI_ARR_AT(v, i) = ffi_int(...). Returns nil if allocation fails. */
static inline FfiObject ffi_array_n(uint32_t n)
{
    FfiObject v = {0};
    v.type = FFIVAL_ARRAY;
    v.array.length = n;
    if (n)
    {
        v.array.elements = (FfiObject *)calloc(n, sizeof(FfiObject));
        if (!v.array.elements)
            return ffi_nil();
    }
    return v;
}

/* Object with n key/value pairs in ONE allocation (keys NULL, values nil).
 * Set pairs[i].key to a malloc'd/strdup'd name the VM will free. */
static inline FfiObject ffi_object_n(uint32_t n)
{
    FfiObject v = {0};
    v.type = FFIVAL_OBJECT;
    v.object.length = n;
    if (n)
    {
        v.object.pairs = (FfiKV *)calloc(n, sizeof(FfiKV));
        if (!v.object.pairs)
            return ffi_nil();
    }
    return v;
}

/* Rowset with nrows x ncols nil cells and NULL column names. Set col_names[c]
 * to malloc'd/strdup'd names and fill cells via FFI_TBL_CELL(v, r, c) = ... .
 * The cheapest way to return database-style results. Returns nil on
 * allocation failure or if nrows*ncols overflows. */
static inline FfiObject ffi_table_n(uint32_t nrows, uint32_t ncols)
{
    FfiObject v = {0};
    v.type = FFIVAL_TABLE;
    v.table.nrows = nrows;
    v.table.ncols = ncols;
    if (ncols)
    {
        v.table.col_names = (char **)calloc(ncols, sizeof(char *));
        if (!v.table.col_names)
            return ffi_nil();
    }
    uint64_t cells = (uint64_t)nrows * (uint64_t)ncols;
    if (cells)
    {
        if (cells > 0xFFFFFFFFull / sizeof(FfiObject))
        {
            free(v.table.col_names);
            return ffi_nil();
        }
        v.table.cells = (FfiObject *)calloc((size_t)cells, sizeof(FfiObject));
        if (!v.table.cells)
        {
            free(v.table.col_names);
            return ffi_nil();
        }
    }
    return v;
}

/* Look up a key in an FFIVAL_OBJECT argument; NULL if absent. */
static inline FfiObject *ffi_object_get(const FfiObject *o, const char *key)
{
    if (!o || o->type != FFIVAL_OBJECT || !key)
        return NULL;
    for (uint32_t i = 0; i < o->object.length; i++)
    {
        const char *k = o->object.pairs[i].key;
        if (k && strcmp(k, key) == 0)
            return (FfiObject *)&o->object.pairs[i].value;
    }
    return NULL;
}
#endif /* FFI_OBJECT_NO_STDLIB */

/* ── Argument guards (use inside an FFI function body; return nil on failure) ── */
#define REQUIRE_ARGC(n)        \
    do                         \
    {                          \
        if (argc < (n))        \
            return ffi_nil();  \
    } while (0)
#define REQUIRE_TYPE(i, t)       \
    do                           \
    {                            \
        if (args[i].type != (t)) \
            return ffi_nil();    \
    } while (0)
#define REQUIRE_NUMBER(i)                \
    do                                   \
    {                                    \
        if (!IS_NUMBER(args[i]))         \
            return ffi_nil();            \
    } while (0)

#endif
