// redis_ffi.c - Redis FFI plugin for Flaris (via hiredis)
//
// Exposes functions to the Flaris VM:
//   redis_connect(host: string, port: int)  - int  (redisContext* handle, 0 on error)
//   redis_command(conn: int, cmd: string)   - any  (string | int | float | bool | array | nil | { error: string })
//   redis_close(conn: int)                  - bool
//
// All Redis commands go through redis_command - see examples below.
// The return value is mapped to the most natural Flaris type based on the reply.
//
// Build (Linux):
//   gcc -shared -fPIC -O2 -o redis_ffi.so redis_ffi.c -lhiredis
//
// Build (macOS):
//   gcc -shared -fPIC -O2 -o redis_ffi.dylib redis_ffi.c \
//       -I$(brew --prefix hiredis)/include/hiredis \
//       -L$(brew --prefix hiredis)/lib -lhiredis
//
// Build (Windows MinGW):
//   gcc -shared -O2 -o redis_ffi.dll redis_ffi.c -lhiredis -lws2_32
//
// Build (Windows MSVC):
//   cl /LD redis_ffi.c /link hiredis.lib ws2_32.lib
//

#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "../vm/ffi_object.h"

/* Exports flaris_abi_version() so the runtime can verify this plugin was
 * built against a compatible FfiObject layout. */
FLARIS_PLUGIN_ABI()
#include <hiredis.h>

#ifdef _WIN32
  #define RD_EXPORT __declspec(dllexport)
#else
  #define RD_EXPORT
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
static FfiObject make_string_copy(const char *s, size_t len) {
    char *copy = (char *)malloc(len + 1);
    if (!copy) return make_nil();
    memcpy(copy, s, len);
    copy[len] = '\0';
    return make_string_owned(copy, (uint32_t)len);
}
static FfiObject make_error(const char *msg) {
    FfiObject out = ffi_object_n(1);
    if (out.type != FFIVAL_OBJECT) return make_nil();
    out.object.pairs[0].key = strdup("error");
    out.object.pairs[0].value = msg ? make_string_copy(msg, strlen(msg)) : make_nil();
    return out;
}

// ── Convert a redisReply to a Flaris FfiObject ───────────────────────────────

static FfiObject reply_to_ffi(redisReply *r) {
    if (!r) return make_nil();

    switch (r->type) {
        case REDIS_REPLY_NIL:
            return make_nil();

        case REDIS_REPLY_INTEGER:
            return make_int((int64_t)r->integer);

        case REDIS_REPLY_DOUBLE:
            return make_float(r->dval);

        case REDIS_REPLY_BOOL:
            return make_bool(r->integer != 0);

        case REDIS_REPLY_STATUS:
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_VERB:
        case REDIS_REPLY_BIGNUM:
            return make_string_copy(r->str ? r->str : "", r->str ? (size_t)r->len : 0);

        case REDIS_REPLY_ERROR:
            return make_error(r->str);

        case REDIS_REPLY_ARRAY:
        case REDIS_REPLY_SET:
        case REDIS_REPLY_PUSH: {
            // One contiguous allocation for all element nodes.
            FfiObject arr = ffi_array_n((uint32_t)r->elements);
            if (r->elements && arr.type != FFIVAL_ARRAY) return make_error("out of memory");
            for (size_t i = 0; i < r->elements; i++)
                arr.array.elements[i] = reply_to_ffi(r->element[i]);
            return arr;
        }

        case REDIS_REPLY_MAP: {
            // MAP replies come as flat key/value pairs (elements is even)
            size_t npairs = r->elements / 2;
            FfiObject obj = ffi_object_n((uint32_t)npairs);
            if (npairs && obj.type != FFIVAL_OBJECT) return make_error("out of memory");
            for (size_t i = 0; i < npairs; i++) {
                redisReply *k = r->element[i * 2];
                redisReply *v = r->element[i * 2 + 1];
                obj.object.pairs[i].key = k ? strdup(k->str ? k->str : "") : strdup("");
                obj.object.pairs[i].value = reply_to_ffi(v);
            }
            return obj;
        }

        default:
            return make_nil();
    }
}

// ── Exported functions ───────────────────────────────────────────────────────

// redis_connect(host: string, port: int) - int
// Returns a redisContext* as int64, or 0 on failure.
// Default Redis port is 6379.
RD_EXPORT FfiObject redis_connect(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_STRING);
    REQUIRE_TYPE(1, FFIVAL_INT);

    const char *host = args[0].string.data ? args[0].string.data : "127.0.0.1";
    int port = (int)(args[1].ival > 0 ? args[1].ival : 6379);

    redisContext *ctx = redisConnect(host, port);
    if (!ctx) return make_int(0);
    if (ctx->err) {
        redisFree(ctx);
        return make_int(0);
    }

    return make_int((int64_t)(uintptr_t)ctx);
}

// redis_command(conn: int, cmd: string) - any
//
// Send a raw Redis command string. The command is split on spaces; quoted
// arguments with spaces are not supported at this level - use individual
// words separated by spaces for most commands, which covers all common cases:
//
//   redis_command(conn, "PING")                      - "PONG"
//   redis_command(conn, "SET mykey hello")           - "OK"
//   redis_command(conn, "GET mykey")                 - "hello"
//   redis_command(conn, "DEL mykey")                 - 1
//   redis_command(conn, "INCR counter")              - int
//   redis_command(conn, "LPUSH mylist a b c")        - int
//   redis_command(conn, "LRANGE mylist 0 -1")        - array
//   redis_command(conn, "HSET myhash field value")   - int
//   redis_command(conn, "HGET myhash field")         - string
//   redis_command(conn, "EXPIRE mykey 60")           - int (1 = set, 0 = no key)
//   redis_command(conn, "TTL mykey")                 - int (seconds, -1 = no TTL, -2 = not found)
//   redis_command(conn, "EXISTS mykey")              - int (1/0)
//   redis_command(conn, "KEYS pattern:*")            - array
//
// For values that contain spaces, the Flaris wrapper (Redis.fls) splits them
// into argc/argv and uses redisCommandArgv - use the high-level methods instead.
RD_EXPORT FfiObject redis_command(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_STRING);

    redisContext *ctx = (redisContext *)(uintptr_t)(uint64_t)args[0].ival;
    if (!ctx) return make_error("invalid connection handle");

    const char *cmd = args[1].string.data;
    if (!cmd) return make_error("command is nil");

    // Split the command on whitespace and dispatch through redisCommandArgv so
    // the command text is never treated as a printf format string. Passing it
    // straight to redisCommand(ctx, cmd) would interpret any '%' in the command
    // as a format specifier, reading nonexistent varargs (UB / crash / info leak).
    size_t cmdlen = (size_t)args[1].string.length;
    char *scratch = (char *)malloc(cmdlen + 1);
    if (!scratch) return make_error("out of memory");
    memcpy(scratch, cmd, cmdlen);
    scratch[cmdlen] = '\0';

    // At most (cmdlen + 1) / 2 tokens for a space-separated string; cmdlen + 1 is a safe bound.
    const char **argv    = (const char **)malloc(sizeof(char *) * (cmdlen + 1));
    size_t      *argvlen = (size_t *)malloc(sizeof(size_t) * (cmdlen + 1));
    if (!argv || !argvlen) { free(scratch); free(argv); free(argvlen); return make_error("out of memory"); }

    int nargs = 0;
    char *p = scratch;
    while (*p) {
        while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
        if (!*p) break;
        char *start = p;
        while (*p && *p != ' ' && *p != '\t' && *p != '\r' && *p != '\n') p++;
        argv[nargs]    = start;
        argvlen[nargs] = (size_t)(p - start);
        nargs++;
        if (*p) *p++ = '\0';
    }

    if (nargs == 0) { free(scratch); free(argv); free(argvlen); return make_error("empty command"); }

    redisReply *reply = (redisReply *)redisCommandArgv(ctx, nargs, argv, argvlen);
    free(scratch);
    free(argv);
    free(argvlen);

    if (!reply) return make_error(ctx->errstr);

    FfiObject out = reply_to_ffi(reply);
    freeReplyObject(reply);
    return out;
}

// redis_command_argv(conn: int, args_array: array) - any
// Lower-level call with pre-split arguments - safe for values with spaces.
// Each element in args_array must be a string.
// Used internally by Redis.fls for Set, HSet, Publish, etc.
RD_EXPORT FfiObject redis_command_argv(FfiObject *args, int argc) {
    REQUIRE_ARGC(2);
    REQUIRE_TYPE(0, FFIVAL_INT);
    REQUIRE_TYPE(1, FFIVAL_ARRAY);

    redisContext *ctx = (redisContext *)(uintptr_t)(uint64_t)args[0].ival;
    if (!ctx) return make_error("invalid connection handle");

    uint32_t nargs = args[1].array.length;
    if (nargs == 0) return make_error("empty command");

    const char **argv  = (const char **)malloc(sizeof(char *) * nargs);
    size_t      *argvlen = (size_t *)malloc(sizeof(size_t) * nargs);
    if (!argv || !argvlen) { free(argv); free(argvlen); return make_error("out of memory"); }

    for (uint32_t i = 0; i < nargs; i++) {
        FfiObject *el = args[1].array.elements ? &args[1].array.elements[i] : NULL;
        if (el && el->type == FFIVAL_STRING && el->string.data) {
            argv[i]    = el->string.data;
            argvlen[i] = (size_t)el->string.length;
        } else {
            argv[i]    = "";
            argvlen[i] = 0;
        }
    }

    redisReply *reply = (redisReply *)redisCommandArgv(ctx, (int)nargs, argv, argvlen);
    free(argv);
    free(argvlen);

    if (!reply) return make_error(ctx->errstr);
    FfiObject out = reply_to_ffi(reply);
    freeReplyObject(reply);
    return out;
}

// redis_close(conn: int) - bool
RD_EXPORT FfiObject redis_close(FfiObject *args, int argc) {
    REQUIRE_ARGC(1);
    REQUIRE_TYPE(0, FFIVAL_INT);

    redisContext *ctx = (redisContext *)(uintptr_t)(uint64_t)args[0].ival;
    if (!ctx) return make_bool(0);

    redisFree(ctx);
    return make_bool(1);
}
