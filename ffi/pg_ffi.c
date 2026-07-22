// pg_ffi.c - PostgreSQL FFI plugin for Flaris
//
// Exposes 8 functions to the Flaris VM:
//   pg_connect(connstr: string)                          - int   (PGconn* as opaque int64)
//   pg_query(conn: int, sql: string)                    - array<object> | { error: string }
//   pg_query_params(conn: int, sql: string, params: array) - array<object> | { error: string }
//   pg_exec(conn: int, sql: string)                     - int   (affected row count, -1 on error)
//   pg_exec_params(conn: int, sql: string, params: array) - int   (affected row count, -1 on error)
//   pg_scalar_int(conn: int, sql: string)               - int | nil
//   pg_scalar_string(conn: int, sql: string)            - string | nil
//   pg_close(conn: int)                                 - bool
//
// Build (Linux):
//   gcc -shared -fPIC -o pg_ffi.so pg_ffi.c -lpq
//
// Build (macOS):
//   gcc -shared -fPIC -o pg_ffi.dylib pg_ffi.c -lpq
//
// Build (Windows MinGW):
//   gcc -shared -o pg_ffi.dll pg_ffi.c -lpq
//
// Build (Windows MSVC):
//   cl /LD pg_ffi.c /link libpq.lib
//
// After building, get the SHA-256 for Flaris:
//   flarisvm --sha256 pg_ffi.so     (Linux)
//   flarisvm --sha256 pg_ffi.dylib  (macOS)
//   flarisvm --sha256 pg_ffi.dll    (Windows)
//
// Or use the provided build_pg.sh script which compiles and patches the hash
// into Postgres.fls automatically.

#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "../vm/ffi_object.h"

/* Exports flaris_abi_version() so the runtime can verify this plugin was
 * built against a compatible FfiObject layout. */
FLARIS_PLUGIN_ABI()

// libpq - available on all platforms via PostgreSQL client package
#include <libpq-fe.h>

// ── Platform export macro ────────────────────────────────────────────────────
#ifdef _WIN32
  #define PG_EXPORT __declspec(dllexport)
#else
  #define PG_EXPORT
#endif

// ── PostgreSQL OID constants for type detection ──────────────────────────────
#define PG_OID_BOOL     16
#define PG_OID_INT2     21
#define PG_OID_INT4     23
#define PG_OID_INT8     20
#define PG_OID_FLOAT4  700
#define PG_OID_FLOAT8  701
#define PG_OID_NUMERIC 1700

// ── FfiObject helpers ────────────────────────────────────────────────────────

static FfiObject make_nil(void) {
    FfiObject v = {0};
    v.type = FFIVAL_NIL;
    return v;
}

static FfiObject make_int(int64_t x) {
    FfiObject v = {0};
    v.type = FFIVAL_INT;
    v.ival = x;
    return v;
}

static FfiObject make_float(double x) {
    FfiObject v = {0};
    v.type = FFIVAL_FLOAT;
    v.fval = x;
    return v;
}

static FfiObject make_bool(int b) {
    FfiObject v = {0};
    v.type = FFIVAL_BOOL;
    v.ival = b ? 1 : 0;
    return v;
}

// Caller must pass a malloc'd buffer - VM frees string.data after conversion.
static FfiObject make_string_owned(char *buf, uint32_t len) {
    FfiObject v = {0};
    v.type = FFIVAL_STRING;
    v.string.data = buf;
    v.string.length = len;
    return v;
}

static FfiObject make_string_copy(const char *s) {
    if (!s) return make_nil();
    size_t len = strlen(s);
    char *copy = (char *)malloc(len + 1);
    if (!copy) return make_nil();
    memcpy(copy, s, len + 1);
    return make_string_owned(copy, (uint32_t)len);
}

// Build { error: "message" } object - used to surface query errors to Flaris.
static FfiObject make_error(const char *msg) {
    FfiObject out = ffi_object_n(1);
    if (out.type != FFIVAL_OBJECT) return make_nil();

    out.object.pairs[0].key = strdup("error");
    out.object.pairs[0].value = make_string_copy(msg ? msg : "unknown error");
    return out;
}

// ── Type-aware column value builder ─────────────────────────────────────────
// Maps PostgreSQL OID + text value - the most natural FfiObject type.
// Falls back to string for anything not explicitly handled.

static FfiObject pg_cell_value(PGresult *res, int row, int col) {
    if (PQgetisnull(res, row, col))
        return make_nil();

    const char *val  = PQgetvalue(res, row, col);
    Oid         oid  = PQftype(res, col);

    switch (oid) {
        case PG_OID_INT2:
        case PG_OID_INT4:
        case PG_OID_INT8:
            return make_int((int64_t)strtoll(val, NULL, 10));

        case PG_OID_FLOAT4:
        case PG_OID_FLOAT8:
        case PG_OID_NUMERIC:
            return make_float(strtod(val, NULL));

        case PG_OID_BOOL:
            // PostgreSQL returns 't' or 'f'
            return make_bool(val[0] == 't' || val[0] == 'T');

        default:
            return make_string_copy(val);
    }
}

// ── Build result table from a completed PGresult ─────────────────────────────
// FFIVAL_TABLE: column names stated once + one contiguous cell block, so a
// whole result set costs a handful of allocations. The VM converts a table to
// an array of row objects: Flaris receives [{ col: value, ... }, ...].

static FfiObject pg_build_result(PGresult *res) {
    uint32_t nrows = (uint32_t)PQntuples(res);
    uint32_t ncols = (uint32_t)PQnfields(res);

    FfiObject t = ffi_table_n(nrows, ncols);
    if (t.type != FFIVAL_TABLE) return make_error("out of memory");

    for (uint32_t c = 0; c < ncols; c++)
        t.table.col_names[c] = strdup(PQfname(res, (int)c));

    for (uint32_t r = 0; r < nrows; r++)
        for (uint32_t c = 0; c < ncols; c++)
            FFI_TBL_CELL(t, r, c) = pg_cell_value(res, (int)r, (int)c);

    return t;
}

// ── Convert a single FfiObject parameter to a libpq text-format string ───────
// buf must be at least 64 bytes for numeric conversions.
// Returns NULL for SQL NULL (FFIVAL_NIL).
// Returns a pointer into buf, args[i].string.data, or a string literal - never
// a heap allocation, so callers must not free the returned pointer.

static const char *ffi_to_pg_param(const FfiObject *v, char *buf, size_t bufsz) {
    if (!v || v->type == FFIVAL_NIL) return NULL;
    switch (v->type) {
        case FFIVAL_INT:
            snprintf(buf, bufsz, "%" PRId64, v->ival);
            return buf;
        case FFIVAL_FLOAT:
            snprintf(buf, bufsz, "%.17g", v->fval);
            return buf;
        case FFIVAL_BOOL:
            return v->ival ? "t" : "f";
        case FFIVAL_STRING:
            return v->string.data ? v->string.data : "";
        default:
            return NULL;
    }
}

// ── Exported functions ───────────────────────────────────────────────────────

// pg_connect(connstr: string) - int
// Returns the PGconn* cast to int64. Returns 0 on failure.
PG_EXPORT FfiObject pg_connect(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_STRING);

    const char *connstr = args[0].string.data;
    if (!connstr) return make_int(0);

    PGconn *conn = PQconnectdb(connstr);
    if (!conn) return make_int(0);

    if (PQstatus(conn) != CONNECTION_OK) {
        PQfinish(conn);
        return make_int(0);
    }

    return make_int((int64_t)(uintptr_t)conn);
}

// pg_query(conn: int, sql: string) - array<object> | { error: string }
// Each row becomes a Flaris object with column names as keys.
// Typed: INT/FLOAT/BOOL columns are returned as native types, not strings.
PG_EXPORT FfiObject pg_query(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_error("invalid connection handle");

    const char *sql = args[1].string.data;
    if (!sql) return make_error("sql is nil");

    PGresult *res = PQexec(conn, sql);
    if (!res) return make_error("query execution failed");

    ExecStatusType status = PQresultStatus(res);
    if (status != PGRES_TUPLES_OK && status != PGRES_COMMAND_OK) {
        FfiObject err = make_error(PQresultErrorMessage(res));
        PQclear(res);
        return err;
    }

    FfiObject out = pg_build_result(res);
    PQclear(res);
    return out;
}

// pg_query_params(conn: int, sql: string, params: array) - array<object> | { error: string }
// Parameterized query - safe alternative to string interpolation.
// Params array elements: int, float, bool, string - text-format PostgreSQL params.
// nil elements become SQL NULL.
// Use $1, $2, ... placeholders in the SQL string.
PG_EXPORT FfiObject pg_query_params(FfiObject *args, int argc) {
    REQUIRE_ARGC(3);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);
    REQUIRE_TYPE(2, FFIVAL_ARRAY);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_error("invalid connection handle");

    const char *sql = args[1].string.data;
    if (!sql) return make_error("sql is nil");

    uint32_t nparams = args[2].array.length;

    const char **param_values = (const char **)malloc(sizeof(char *) * (nparams + 1));
    char        *num_bufs     = (char *)malloc(64 * (nparams + 1));
    if (!param_values || !num_bufs) {
        free(param_values);
        free(num_bufs);
        return make_error("out of memory");
    }

    for (uint32_t i = 0; i < nparams; i++) {
        FfiObject *el = args[2].array.elements ? &args[2].array.elements[i] : NULL;
        param_values[i] = ffi_to_pg_param(el, num_bufs + i * 64, 64);
    }

    PGresult *res = PQexecParams(conn, sql, (int)nparams,
                                  NULL,          // paramTypes: let PostgreSQL infer
                                  param_values,
                                  NULL,          // paramLengths: text format
                                  NULL,          // paramFormats: text format
                                  0);            // result format: text
    free(param_values);
    free(num_bufs);

    if (!res) return make_error("query execution failed");

    ExecStatusType status = PQresultStatus(res);
    if (status != PGRES_TUPLES_OK && status != PGRES_COMMAND_OK) {
        FfiObject err = make_error(PQresultErrorMessage(res));
        PQclear(res);
        return err;
    }

    FfiObject out = pg_build_result(res);
    PQclear(res);
    return out;
}

// pg_exec(conn: int, sql: string) - int
// Execute a DML statement (INSERT / UPDATE / DELETE / DDL).
// Returns the number of affected rows, or -1 on error.
// Use pg_exec_params for safe parameterized DML.
PG_EXPORT FfiObject pg_exec(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_int(-1);

    const char *sql = args[1].string.data;
    if (!sql) return make_int(-1);

    PGresult *res = PQexec(conn, sql);
    if (!res) return make_int(-1);

    ExecStatusType status = PQresultStatus(res);
    if (status != PGRES_COMMAND_OK && status != PGRES_TUPLES_OK) {
        PQclear(res);
        return make_int(-1);
    }

    const char *tuples = PQcmdTuples(res);
    int64_t count = (tuples && tuples[0]) ? (int64_t)strtoll(tuples, NULL, 10) : 0;
    PQclear(res);
    return make_int(count);
}

// pg_exec_params(conn: int, sql: string, params: array) - int
// Parameterized DML - use $1, $2, ... placeholders.
// Returns affected row count, or -1 on error.
PG_EXPORT FfiObject pg_exec_params(FfiObject *args, int argc) {
    REQUIRE_ARGC(3);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);
    REQUIRE_TYPE(2, FFIVAL_ARRAY);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_int(-1);

    const char *sql = args[1].string.data;
    if (!sql) return make_int(-1);

    uint32_t nparams = args[2].array.length;

    const char **param_values = (const char **)malloc(sizeof(char *) * (nparams + 1));
    char        *num_bufs     = (char *)malloc(64 * (nparams + 1));
    if (!param_values || !num_bufs) {
        free(param_values);
        free(num_bufs);
        return make_int(-1);
    }

    for (uint32_t i = 0; i < nparams; i++) {
        FfiObject *el = args[2].array.elements ? &args[2].array.elements[i] : NULL;
        param_values[i] = ffi_to_pg_param(el, num_bufs + i * 64, 64);
    }

    PGresult *res = PQexecParams(conn, sql, (int)nparams,
                                  NULL, param_values, NULL, NULL, 0);
    free(param_values);
    free(num_bufs);

    if (!res) return make_int(-1);

    ExecStatusType status = PQresultStatus(res);
    if (status != PGRES_COMMAND_OK && status != PGRES_TUPLES_OK) {
        PQclear(res);
        return make_int(-1);
    }

    const char *tuples = PQcmdTuples(res);
    int64_t count = (tuples && tuples[0]) ? (int64_t)strtoll(tuples, NULL, 10) : 0;
    PQclear(res);
    return make_int(count);
}

// pg_scalar_int(conn: int, sql: string) - int | nil
// Fast path for queries that return a single integer (COUNT, MAX, etc.)
PG_EXPORT FfiObject pg_scalar_int(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_nil();

    const char *sql = args[1].string.data;
    if (!sql) return make_nil();

    PGresult *res = PQexec(conn, sql);
    if (!res) return make_nil();

    if (PQresultStatus(res) != PGRES_TUPLES_OK ||
        PQntuples(res) == 0 || PQnfields(res) == 0) {
        PQclear(res);
        return make_nil();
    }

    FfiObject out = make_nil();
    if (!PQgetisnull(res, 0, 0)) {
        const char *val = PQgetvalue(res, 0, 0);
        out = make_int((int64_t)strtoll(val, NULL, 10));
    }

    PQclear(res);
    return out;
}

// pg_scalar_string(conn: int, sql: string) - string | nil
// Fast path for queries that return a single string value.
PG_EXPORT FfiObject pg_scalar_string(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_nil();

    const char *sql = args[1].string.data;
    if (!sql) return make_nil();

    PGresult *res = PQexec(conn, sql);
    if (!res) return make_nil();

    if (PQresultStatus(res) != PGRES_TUPLES_OK ||
        PQntuples(res) == 0 || PQnfields(res) == 0) {
        PQclear(res);
        return make_nil();
    }

    FfiObject out = make_nil();
    if (!PQgetisnull(res, 0, 0)) {
        out = make_string_copy(PQgetvalue(res, 0, 0));
    }

    PQclear(res);
    return out;
}

// pg_close(conn: int) - bool
// Closes the connection and frees libpq resources.
PG_EXPORT FfiObject pg_close(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_INT);

    PGconn *conn = (PGconn *)(uintptr_t)(uint64_t)args[0].ival;
    if (!conn) return make_bool(0);

    PQfinish(conn);
    return make_bool(1);
}
