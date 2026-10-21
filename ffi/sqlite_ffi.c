// sqlite_ffi.c - SQLite FFI plugin for Flaris
//
// Exposes 8 functions to the Flaris VM:
//   sqlite_open(path: string)                            - int  (sqlite3* handle, 0 on error)
//   sqlite_query(db: int, sql: string)                    - array<object> | { error: string }
//   sqlite_query_params(db: int, sql: string, params: array) - array<object> | { error: string }
//   sqlite_exec(db: int, sql: string)                     - int  (affected rows, -1 on error)
//   sqlite_exec_params(db: int, sql: string, params: array) - int  (affected rows, -1 on error)
//   sqlite_last_error(db: int)                            - string | nil  (last error message, nil if none)
//   sqlite_last_insert_id(db: int)                        - int
//   sqlite_close(db: int)                                 - bool
//
// Parameters bind nil, int, float, bool, string and block (as a BLOB);
// BLOB cells come back as byte blocks.
//
// Build from the repo root (ffi_object.h sits next to this file), or run
// ffi/build_sqlite_ffi.sh:
//
// Build (Linux):
//   gcc -shared -fPIC -O2 -I ffi -o sqlite_ffi.so ffi/sqlite_ffi.c -lsqlite3
//
// Build (macOS):
//   gcc -shared -fPIC -O2 -I ffi -o sqlite_ffi.dylib ffi/sqlite_ffi.c -lsqlite3
//
// Build (Windows MinGW):
//   gcc -shared -O2 -I ffi -o sqlite_ffi.dll ffi/sqlite_ffi.c -lsqlite3
//
// Build (Windows MSVC):
//   cl /LD /I ffi ffi/sqlite_ffi.c /link sqlite3.lib
//

#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "ffi_object.h"

/* Exports flaris_abi_version() so the runtime can verify this plugin was
 * built against a compatible FfiObject layout. */
FLARIS_PLUGIN_ABI()

// Optional self-contained build: compile with
//   -DFLARIS_SQLITE_AMALGAMATION -I/path/to/sqlite-amalgamation
// and place sqlite3.c/sqlite3.h in that include path.
#ifdef FLARIS_SQLITE_AMALGAMATION
#include "sqlite3.c"
#else
#include <sqlite3.h>
#endif

#ifdef _WIN32
  #define SQ_EXPORT __declspec(dllexport)
#else
  #define SQ_EXPORT
#endif

// ── FfiObject helpers ────────────────────────────────────────────────────────

static FfiObject make_nil(void) {
    FfiObject v = {0}; v.type = FFIVAL_NIL; return v;
}
static FfiObject make_int(int64_t x) {
    FfiObject v = {0}; v.type = FFIVAL_INT; v.ival = x; return v;
}
static FfiObject make_float(double x) {
    FfiObject v = {0}; v.type = FFIVAL_FLOAT; v.fval = x; return v;
}
static FfiObject make_bool(int b) {
    FfiObject v = {0}; v.type = FFIVAL_BOOL; v.ival = b ? 1 : 0; return v;
}
static FfiObject make_string_owned(char *buf, uint32_t len) {
    FfiObject v = {0}; v.type = FFIVAL_STRING; v.string.data = buf; v.string.length = len; return v;
}
static FfiObject make_string_copy(const char *s) {
    if (!s) return make_nil();
    size_t len = strlen(s);
    char *copy = (char *)malloc(len + 1);
    if (!copy) return make_nil();
    memcpy(copy, s, len + 1);
    return make_string_owned(copy, (uint32_t)len);
}
// A byte block the VM adopts. Never NULL memory, so an empty blob is an empty
// block rather than nil.
static FfiObject make_block_copy(const void *data, int len) {
    size_t n = len > 0 ? (size_t)len : 0;
    void *mem = malloc(n ? n : 1);
    if (!mem) return make_nil();
    if (n) memcpy(mem, data, n);
    FfiObject v = {0};
    v.type = FFIVAL_BLOCK;
    v.block.memory = mem;
    v.block.block_size = 1;
    v.block.block_count = (uint32_t)n;
    return v;
}

// Frees cells that were built but never handed to the VM.
static void free_cells(FfiObject *cells, size_t n) {
    for (size_t i = 0; i < n; i++) {
        if (cells[i].type == FFIVAL_STRING) free(cells[i].string.data);
        else if (cells[i].type == FFIVAL_BLOCK) free(cells[i].block.memory);
    }
    free(cells);
}

static FfiObject make_error(const char *msg) {
    FfiObject out = ffi_object_n(1);
    if (out.type != FFIVAL_OBJECT) return make_nil();
    out.object.pairs[0].key = strdup("error");
    out.object.pairs[0].value = make_string_copy(msg ? msg : "unknown error");
    return out;
}

// ── Build one cell from the statement's current cursor position ──────────────

static FfiObject sqlite_cell_value(sqlite3_stmt *stmt, int c) {
    switch (sqlite3_column_type(stmt, c)) {
        case SQLITE_NULL:
            return make_nil();
        case SQLITE_INTEGER:
            return make_int((int64_t)sqlite3_column_int64(stmt, c));
        case SQLITE_FLOAT:
            return make_float(sqlite3_column_double(stmt, c));
        case SQLITE_TEXT:
            return make_string_copy((const char *)sqlite3_column_text(stmt, c));
        case SQLITE_BLOB:
            return make_block_copy(sqlite3_column_blob(stmt, c), sqlite3_column_bytes(stmt, c));
        default:
            return make_nil();
    }
}

// ── Bind a Flaris FfiObject to a prepared statement parameter ────────────────

static int sqlite_bind_param(sqlite3_stmt *stmt, int idx, const FfiObject *v) {
    if (!v || v->type == FFIVAL_NIL)
        return sqlite3_bind_null(stmt, idx);
    switch (v->type) {
        case FFIVAL_INT:
            return sqlite3_bind_int64(stmt, idx, (sqlite3_int64)v->ival);
        case FFIVAL_FLOAT:
            return sqlite3_bind_double(stmt, idx, v->fval);
        case FFIVAL_BOOL:
            return sqlite3_bind_int(stmt, idx, v->ival ? 1 : 0);
        case FFIVAL_STRING:
            return sqlite3_bind_text(stmt, idx,
                                     v->string.data ? v->string.data : "",
                                     v->string.data ? (int)v->string.length : 0,
                                     SQLITE_TRANSIENT);
        case FFIVAL_BLOCK:
            return sqlite3_bind_blob64(stmt, idx,
                                       v->block.memory ? v->block.memory : "",
                                       v->block.memory ? (sqlite3_uint64)FFI_BLOCK_BYTES(*v) : 0,
                                       SQLITE_TRANSIENT);
        default:
            return sqlite3_bind_null(stmt, idx);
    }
}

// ── Execute a prepared statement and collect rows into a table ───────────────
// FFIVAL_TABLE: column names stated once + one contiguous, row-chunk-grown
// cell block. The VM converts a table to an array of row objects: Flaris
// receives [{ col: value, ... }, ...].

static FfiObject sqlite_run_stmt(sqlite3 *db, sqlite3_stmt *stmt) {
    uint32_t ncols = (uint32_t)sqlite3_column_count(stmt);

    char **col_names = ncols ? (char **)calloc(ncols, sizeof(char *)) : NULL;
    if (ncols && !col_names) { sqlite3_finalize(stmt); return make_error("out of memory"); }
    for (uint32_t c = 0; c < ncols; c++) {
        const char *name = sqlite3_column_name(stmt, (int)c);
        col_names[c] = strdup(name ? name : "");
    }

    size_t cap_rows = 8;
    FfiObject *cells = ncols ? (FfiObject *)malloc(sizeof(FfiObject) * cap_rows * ncols) : NULL;
    if (ncols && !cells) {
        for (uint32_t c = 0; c < ncols; c++) free(col_names[c]);
        free(col_names);
        sqlite3_finalize(stmt);
        return make_error("out of memory");
    }

    uint32_t nrows = 0;
    int rc;
    while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
        if (ncols == 0) { nrows++; continue; }
        if (nrows >= cap_rows) {
            cap_rows *= 2;
            FfiObject *tmp = (FfiObject *)realloc(cells, sizeof(FfiObject) * cap_rows * ncols);
            if (!tmp) {
                // Report OOM instead of silently truncating: falling through with
                // rc == SQLITE_ROW would look like a successful (short) result.
                free_cells(cells, (size_t)nrows * ncols);
                for (uint32_t c = 0; c < ncols; c++) free(col_names[c]);
                free(col_names);
                sqlite3_finalize(stmt);
                return make_error("out of memory");
            }
            cells = tmp;
        }
        for (uint32_t c = 0; c < ncols; c++)
            cells[(size_t)nrows * ncols + c] = sqlite_cell_value(stmt, (int)c);
        nrows++;
    }

    if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
        // Step error - free what we built and return error
        free_cells(cells, (size_t)nrows * ncols);
        for (uint32_t c = 0; c < ncols; c++) free(col_names[c]);
        free(col_names);
        FfiObject err = make_error(sqlite3_errmsg(db));
        sqlite3_finalize(stmt);
        return err;
    }

    sqlite3_finalize(stmt);
    FfiObject t = {0};
    t.type = FFIVAL_TABLE;
    t.table.ncols = ncols;
    t.table.nrows = nrows;
    t.table.col_names = col_names;
    t.table.cells = cells;
    return t;
}

// ── Exported functions ───────────────────────────────────────────────────────

// sqlite_open(path: string) - int
// Opens (or creates) a SQLite database file. Returns handle or 0 on failure.
// Pass ":memory:" for an in-memory database.
SQ_EXPORT FfiObject sqlite_open(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_STRING);

    const char *path = args[0].string.data;
    if (!path) return make_int(0);

    sqlite3 *db = NULL;
    int rc = sqlite3_open(path, &db);
    if (rc != SQLITE_OK) {
        if (db) sqlite3_close(db);
        return make_int(0);
    }

    sqlite3_busy_timeout(db, 5000);  // 5 s busy timeout
    return make_int((int64_t)(uintptr_t)db);
}

// sqlite_query(db: int, sql: string) - array<object> | { error: string }
SQ_EXPORT FfiObject sqlite_query(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_error("invalid db handle");
    const char *sql = args[1].string.data;
    if (!sql) return make_error("sql is nil");

    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) return make_error(sqlite3_errmsg(db));

    return sqlite_run_stmt(db, stmt);
}

// sqlite_query_params(db: int, sql: string, params: array) - array<object> | { error: string }
SQ_EXPORT FfiObject sqlite_query_params(FfiObject *args, int argc) {
    REQUIRE_ARGC(3);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);
    REQUIRE_TYPE(2, FFIVAL_ARRAY);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_error("invalid db handle");
    const char *sql = args[1].string.data;
    if (!sql) return make_error("sql is nil");

    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) return make_error(sqlite3_errmsg(db));

    uint32_t nparams = args[2].array.length;
    int expected = sqlite3_bind_parameter_count(stmt);
    if ((int)nparams != expected) {
        FfiObject err = make_error("parameter count mismatch");
        sqlite3_finalize(stmt);
        return err;
    }
    for (uint32_t i = 0; i < nparams; i++) {
        FfiObject *el = args[2].array.elements ? &args[2].array.elements[i] : NULL;
        rc = sqlite_bind_param(stmt, (int)(i + 1), el);
        if (rc != SQLITE_OK) {
            FfiObject err = make_error(sqlite3_errmsg(db));
            sqlite3_finalize(stmt);
            return err;
        }
    }

    return sqlite_run_stmt(db, stmt);
}

// sqlite_exec(db: int, sql: string) - int  (affected rows, -1 on error)
SQ_EXPORT FfiObject sqlite_exec(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_int(-1);
    const char *sql = args[1].string.data;
    if (!sql) return make_int(-1);

    // Execute every statement in sql, following pzTail, so batches such as
    // "BEGIN; ...; COMMIT" run in full rather than only the first statement.
    const char *tail = sql;
    int64_t total_changes = 0;
    int ran_any = 0;
    while (tail && *tail) {
        sqlite3_stmt *stmt = NULL;
        int rc = sqlite3_prepare_v2(db, tail, -1, &stmt, &tail);
        if (rc != SQLITE_OK) return make_int(-1);
        if (!stmt) continue; // trailing whitespace / comment - nothing to run
        ran_any = 1;
        rc = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        if (rc != SQLITE_DONE && rc != SQLITE_ROW) return make_int(-1);
        total_changes += (int64_t)sqlite3_changes(db);
    }
    if (!ran_any) return make_int(0);
    return make_int(total_changes);
}

// sqlite_exec_params(db: int, sql: string, params: array) - int  (affected rows, -1 on error)
SQ_EXPORT FfiObject sqlite_exec_params(FfiObject *args, int argc) {
    REQUIRE_ARGC(3);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);
    REQUIRE_TYPE(2, FFIVAL_ARRAY);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_int(-1);
    const char *sql = args[1].string.data;
    if (!sql) return make_int(-1);

    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) return make_int(-1);

    uint32_t nparams = args[2].array.length;
    int expected = sqlite3_bind_parameter_count(stmt);
    if ((int)nparams != expected) { sqlite3_finalize(stmt); return make_int(-1); }
    for (uint32_t i = 0; i < nparams; i++) {
        FfiObject *el = args[2].array.elements ? &args[2].array.elements[i] : NULL;
        rc = sqlite_bind_param(stmt, (int)(i + 1), el);
        if (rc != SQLITE_OK) { sqlite3_finalize(stmt); return make_int(-1); }
    }

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    if (rc != SQLITE_DONE && rc != SQLITE_ROW) return make_int(-1);
    return make_int((int64_t)sqlite3_changes(db));
}

// sqlite_last_error(db: int) - string | nil
// Returns the last SQLite error message, or nil if the last operation succeeded.
SQ_EXPORT FfiObject sqlite_last_error(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_INT);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_nil();
    int code = sqlite3_errcode(db);
    if (code == SQLITE_OK || code == SQLITE_DONE || code == SQLITE_ROW) return make_nil();
    return make_string_copy(sqlite3_errmsg(db));
}

// sqlite_last_insert_id(db: int) - int
SQ_EXPORT FfiObject sqlite_last_insert_id(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_INT);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_int(0);
    return make_int((int64_t)sqlite3_last_insert_rowid(db));
}

// sqlite_close(db: int) - bool
SQ_EXPORT FfiObject sqlite_close(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_INT);

    sqlite3 *db = (sqlite3 *)(uintptr_t)(uint64_t)args[0].ival;
    if (!db) return make_bool(0);
    int rc = sqlite3_close_v2(db);
    return make_bool(rc == SQLITE_OK);
}
